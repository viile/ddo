import std.stdio;

import ddo.database;
import ddo.driver.mysql;

void main()
{
	writeln("Edit source/app.d to start your project.");
	auto mysql = mysql_init(null);
	char value = 1; 
	mysql_options(mysql, mysql_option.MYSQL_OPT_RECONNECT, cast(char*)&value);
	size_t read_timeout = 60;
	mysql_options(mysql, mysql_option.MYSQL_OPT_READ_TIMEOUT, cast(size_t*)&read_timeout);
	mysql_options(mysql, mysql_option.MYSQL_OPT_WRITE_TIMEOUT, cast(size_t*)&read_timeout);
	mysql_real_connect(mysql, toCstring("10.1.11.31"), toCstring("dev"),
			toCstring("111111"), toCstring("blog"), 3306, null, 0);
	mysql_query(mysql, toCstring("SET NAMES 'utf8'"));
	string sql = "select * from user;";
	mysql_query(mysql, toCstring(sql));
	writeln(mysql_store_result(mysql), sql);
}
