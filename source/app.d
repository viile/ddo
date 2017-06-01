import std.stdio;

import ddo.database;

void main()
{
	writeln("Edit source/app.d to start your project.");
	auto db = new MySql("10.1.11.31","dev","111111","blog",3306);
	writeln(db.error());
	writeln(db.pingMysql());
	writeln(db.clientInfo());
	writeln(db.insert("user",["username":"1"]));
	db.close();
	writeln("close");
}
