#! /Users/joe/.rvm/bin/rvm-auto-ruby
# encoding: utf-8

require 'amalgalite'
require 'csv'


#require 'spreadsheet' #this is is for the mac.  For windows use win32ole


Dir.foreach("./") do |filename| # always delete query results from the previous run before creating new ones
  File.delete(filename) if filename.start_with? 'QUERYRESULT_'
end
$querynumber = 0
$db = Amalgalite::Database.new( "my.db" )  # .new(":memory:") or .new("my.db")  #note that this always overwrites the previous db

class Object
# Useage: puts show_methods(CSV) #This is just for troubleshooting purposes
  def examine_methods
    klass = self.class
    str = ""
    str += "\nCLASS METHODS FOR #{klass}\n"
    str += "  " + klass.methods(false).sort.join("\n  ")
    str += "\nINSTANCE METHODS FOR #{klass}\n"
    str += "  " + klass.instance_methods(false).sort.join("\n  ")
    puts str
    sleep 100
  end
end

class String # used in COMMENT,UNCOMMENT
  def strip_whitespace_and_singlequotes
    self.gsub!(/^[\s\']*|[\s\']*$/,'')
  end
end

module Stuff
  
  def done
  	  $db.close if $db  #must remove the connection to the database before it can be deleted
  	  File.delete('my.db')
  	  File.delete('myscript')
      puts "\nDone."
      sleep 5
  end

  $db.function('REGEX') do |value, regex|
  #USEAGE WITHIN SQLITE3 SQL: WHERE REGEX(colname, '/.*immi/')
    regex.gsub!(/^\//,'').gsub!(/\/$/,'') #remove the /.../ formatting
    if value and regex then
      value.force_encoding("utf-8")
      regex.force_encoding("utf-8")
      (value =~ /^#{regex}$/i)? true : false
    else
      false
    end
  end

  $db.function('GSUB') do |value, match, replacement|
  #USEAGE WITHIN SQLITE3 SQL:  GSUB(colname,'i.','jj')
    if value.nil? or match.nil?
      value
    else
      value.gsub(/#{match}/, replacement)
    end
  end

  def sqlite_import(filepath, sepstring, tablename, declared_headers)
    File.open("myscript", "w") do |myscript|
    myscript.puts %|
      DROP TABLE IF EXISTS #{tablename}; 
      CREATE VIRTUAL TABLE #{tablename} USING FTS3 (#{declared_headers});
      .separator "#{sepstring}"
      .headers OFF
      .import #{filepath} #{tablename}|.gsub("\n      ","\n") 
      #the gsub above allows me to indent lines like .indent in this SQLite3 script
    end   
    `sqlite3 my.db < myscript`
  end

  def bucket(new_tablename, sqlselect)
    $db.execute_batch(%|DROP TABLE IF EXISTS #{new_tablename};|)
    stmt = $db.prepare(sqlselect)
    declared_headers = stmt.result_fields().join(' TEXT, ') + ' TEXT'    
    $db.execute_batch(%|CREATE VIRTUAL TABLE #{new_tablename} USING FTS3 (#{declared_headers});
                        INSERT INTO #{new_tablename} #{sqlselect};|)
    stmt.close
  end

  def parse_rawtable(rawtable)
    unirow = $db.execute("SELECT onecolumn FROM #{rawtable} LIMIT 1;") #fetch columns string
    header_array = unirow[0].join.split(',') #In a raw table, row one is the col row of the next table
    $db.execute("DELETE FROM #{rawtable} WHERE rowid == 1;") #now remove that headr row from the data
    declared_headers = header_array.join(' TEXT, ') + ' TEXT'
    tablename = rawtable.gsub('raw_','')

    $db.execute("DROP TABLE IF EXISTS #{tablename};")
    $db.execute("CREATE VIRTUAL TABLE #{tablename} USING FTS3 (#{declared_headers});")
    $db.execute("SELECT onecolumn FROM #{rawtable};") do |unirow|
      row_array = CSV.parse(unirow.join).flatten.map(&:strip_whitespace_and_singlequotes)
      row_string = '"' + row_array.join('","') + '"'
      $db.execute("INSERT INTO #{tablename} VALUES(#{row_string});")
    end
    #puts "TABLENAME == #{tablename}"
    #puts "HEADER_ARRAY == #{header_array}"
  end

  def query(sql) 
    $querynumber += 1
    cols,*rows = $db.execute(sql) #this strips off the columns row, but we don't use it
    output_file = "./QUERYRESULT_" + 
    $querynumber.to_s.rjust(2,'0') + "_" + 
    sql.gsub(/\s+/,' ').scan(/(?:FROM|INNER JOIN|OUTER JOIN) ([^ ;]+)/mi).join('_') + ".csv"
    puts
    puts output_file[2..-1]
    puts rows[0].fields.to_s
    CSV.open(output_file, "wb") do |csv|#not a loop
      csv << rows[0].fields
      rows.each do |row|
        puts row.to_s
        csv << row
      end
    end
  end

  def inhale_csv(filepath)
    if filepath =~ /.xls$/
      tablename = File.basename(filepath, '.*') #excel files go straight to SQL table form
      #puts "processing excel file: #{filepath}" 
      Spreadsheet.client_encoding = 'UTF-8'
      book = Spreadsheet.open filepath
      sheet1 = book.worksheet 0
      header_array = sheet1.row(0)
      ###########################################################
#      $db.execute("DROP TABLE IF EXISTS #{metatables};")
#      $db.execute("CREATE VIRTUAL TABLE #{metatables} USING FTS3 (name,headers);")
#      ###########################################################
      declared_headers = header_array.join(' TEXT, ') + ' TEXT'
      $db.execute("DROP TABLE IF EXISTS #{tablename};")
      $db.execute("CREATE VIRTUAL TABLE #{tablename} USING FTS3 (#{declared_headers});")
#      header_string = header_array.join(',')
      arrayset = []
      sheet1.each 1 do |row| #0 starts at first row (headers), 1 starts at 2nd row, etc.
        arrayset << row.to_a unless row.empty?
      end
      arrayset.each do |row|
#        row_array = CSV.parse(unirow.join).flatten.map(&:strip_whitespace_and_singlequotes)
        row_string = '"' + row.to_a.join('","') + '"'
        $db.execute("INSERT INTO #{tablename} VALUES(#{row_string});")
      end
#      query("SELECT * FROM #{tablename};")
#    sleep 10 
      puts "TABLENAME == #{tablename}"
      puts "HEADER_ARRAY == #{header_array}"
      
    else
      tablename = 'raw_' + File.basename(filepath, '.*')
      arrayset = CSV.read(filepath, :skip_blanks => true, :col_sep => ',')
      firstrow = File.open(filepath, &:readline) #This reads just the top line, which should be column names
      header_array = CSV.parse(firstrow).flatten #parse and clean them up
      declared_headers = 'onecolumn TEXT'
      sepstring = '€$@#' #splits on nothing, by intention
      sqlite_import(filepath, sepstring, tablename, declared_headers)
      parse_rawtable(tablename)
    end
  end
end

#################################
#NOTES:
#inhale_csv('wells.csv')
#bucket('apes','SELECT name||"_ape" AS apename, age FROM persons')
#query("SELECT * FROM apes;")
#
#bucket('neanderthals',
#       'SELECT persons.name||"_neanderthal" AS neanderthalname, 
#        car, 
#        age 
#        FROM persons
#        INNER JOIN cars ON persons.name = cars.name')
#query('SELECT * FROM neanderthals;')
#
#
#inhale_csv('cars.csv')
##query("SELECT onecolumn FROM raw_cars;")
##query("SELECT * FROM cars;")
#query('SELECT * FROM cars ORDER BY name ASC;')
##query("SELECT name, age AS years FROM persons;")
##query("SELECT * FROM cars WHERE description MATCH 'injection fuel';") #search on "SQLite3 search application tips rank"
##query("SELECT name, car, GSUB(description,'.nject','infect') AS descr FROM cars WHERE REGEX(description, '/.*inject.*/');")
#
##query("SELECT persons.name, persons.age, GROUP_CONCAT(cars.car,\" * \") AS cars
##       FROM persons LEFT JOIN cars ON persons.name = cars.name 
##       GROUP BY persons.name, persons.age
##       ORDER BY persons.name;")
#       
##query("SELECT SUM(age) AS total_age FROM persons;")
#
#query('SELECT * FROM cars 
#       INNER JOIN persons ON cars.name = persons.name')
#
##--------------------------------------------------

  


