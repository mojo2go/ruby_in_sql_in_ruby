#! /Users/joe/.rvm/bin/rvm-auto-ruby

#To create an exe file:
# cd C:\dev\ped\ruby\sqlite\using_gem_amalgalite\
# ocra --console .\adhoc.rb .\adback.rb .\wells.csv .\platforms.csv .\sqlite3.exe .\sqlite3.dll


$:.unshift File.dirname($0)     #These two lines are is critical for the ocra script, to find the extra files you 
Dir.chdir File.dirname($0)       #name, that happend to be in the same directory as the script that gets turned into an .exe file.

require 'adback.rb'
include Stuff


inhale_csv('wells.csv')  #why not make a convenience method that calls each inhale in sequence, behind the scenes?
inhale_csv('platforms.csv')

query("SELECT * FROM wells")
query("SELECT * FROM platforms")

bucket('staging01', 
          "SELECT wells.id AS well_id, wells.owner_id, wells.platform_id, wells.name, wells.level,  platforms.name AS platname 
           FROM wells INNER JOIN platforms ON wells.platform_id == platforms.id
           WHERE REGEX(platname, '/EK.*/')")

       
query("SELECT * FROM staging01")


done




#Notes:

# SYNTAX
# Note: You cannot use any asterisk in the SELECT of a bucket if you join two tables that share one or more table field names. You will get an error ('close':vtable constructor failed).
# Solution, name each field and rename those that conflict.
# Long term solution.  When the parser sees an asterisk, have it look for dupe fileld names across the tables, and warn you.
# Longer term solution: When the parser sees an asterisk and finds dupes, it does one of two things:
#   renames them both to avoid the name collision.
#   rename all id fields to look like foreign key fiields, then remove duplicates


# OCRA
# In the ocra packaging line above, the dll is needed because the user does not
# have sqlite3 installed.  The exe is included because there is an 
# explicit call to the sqlite3.exe client, in adback.  This entire adhoc file is identical for
# the two gems: SQLITE3 and AMALGALITE except that the amalgalite version does not include the
# file 'sqlite3.dll' since it already includes it in the gem.  


# MISC QUERIES
#inhale_csv('Medlemsliste.xls')
#query(" SELECT 
#        *, 
#        CASE WHEN Epost == '' AND Mobil != '' THEN 'SMS LIST' END AS smslist 
#        FROM medlemsliste
#        ORDER BY smslist DESC")
