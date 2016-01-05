# ruby_in_sql_in_ruby
Make a SQLite table a data structure in ruby


This is useful for data scientist types who write snippets of disposable code to quickly pull data from different data sources, combine the results, run some queries, then report findings.  This library makes it easy work entirely in ruby but have the structure of a real database to add custom functions to SQLite using ruby, and it makes it possible to import external data directly into sqlite tables and to treat them as normal primitives.  Of course the sqlite database contains all the tables so they can be joined, etc.  The syntax of SQL has always bothered me.  In general I believe the langage could be refined to 60% the amount of text.  Since ruby is building SQL code in this library, we have begun to redesign SQL slightly to take advantage of defaults.  For example, if you join two tables you must always specify the keys.  But if you don't, then the code should be able to find an obvious match.


<img src="sqltable_as_a_primitive.jpg">