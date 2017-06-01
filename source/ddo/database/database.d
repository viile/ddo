module ddo.database.database;

import ddo.resultset;
import std.traits;
import std.typecons;
import std.variant;

interface Database {
	/// Actually implements the query for the database. The query() method
	/// below might be easier to use.
	ResultSet queryImpl(string sql, Variant[] args...);

	/// Escapes data for inclusion into an sql string literal
	string escape(string sqlData);

	/// query to start a transaction, only here because sqlite is apparently different in syntax...
	void startTransaction();

	// FIXME: this would be better as a template, but can't because it is an interface

	/// Just executes a query. It supports placeholders for parameters
	/// by using ? in the sql string. NOTE: it only accepts string, int, long, and null types.
	/// Others will fail runtime asserts.
	final ResultSet query(T...)(string sql, T t) {
		Variant[] args;
		foreach(arg; t) {
			Variant a;
			static if(__traits(compiles, a = arg))
				a = arg;
			else
				a = to!string(t);
			args ~= a;
		}
		return queryImpl(sql, args);
	}
	///断开连接
	void close();
}
