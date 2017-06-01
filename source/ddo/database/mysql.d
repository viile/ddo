module ddo.database.mysql;

import std.variant;
import std.string;
import std.conv;

import ddo.driver;
import ddo.database.database;
import ddo.resultset;
import ddo.exception;
import ddo.utils.utils;

class MySql : Database 
{
	this(string host, string user, string pass, string db, uint port) 
	{
		this._port = port;
		this._host = host;
		this._user = user;
		this._db = db;
		this._pass = pass;
		dbname = db;
		this.connect();
	}

	string dbname;
	private{
		string _host, _user, _pass, _db;
		uint _port;

	}

	private void connect()
	{
		try{
			mysql = mysql_init(null);
			char value = 1; 
			mysql_options(mysql, mysql_option.MYSQL_OPT_RECONNECT, cast(char*)&value);
			size_t read_timeout = 60;
			mysql_options(mysql, mysql_option.MYSQL_OPT_READ_TIMEOUT, cast(size_t*)&read_timeout);
			mysql_options(mysql, mysql_option.MYSQL_OPT_WRITE_TIMEOUT, cast(size_t*)&read_timeout);
			mysql_real_connect(mysql, toCstring(_host), toCstring(_user), toCstring(_pass), toCstring(_db), _port, null, 0);
			query("SET NAMES 'utf8'");
		}
		catch(DatabaseException ex)
		{
			std.stdio.writeln(error());
		}

	}

	override void startTransaction() {
		query("START TRANSACTION");
	}

	string clientInfo()
	{
		return fromCstring(mysql_get_client_info());
	}

	string error() {
		return fromCstring(mysql_error(mysql));
	}

	void close() {
		try{
			mysql_close(mysql);
		}catch(Exception ex)
		{
		}
	}

	~this() {
	}

	///ping mysql
	int pingMysql()
	{
		return mysql_ping(mysql);
	}

	///
	size_t getThreadId()
	{
		return mysql_thread_id(mysql);
	}

	public int lastInsertId() {
		return cast(int) mysql_insert_id(mysql);
	}

	int insert(string table, MySqlResult result, string[string] columnsToModify, string[] columnsToSkip) {
		assert(!result.empty);
		string sql = "INSERT INTO `" ~ table ~ "` ";

		string cols = "(";
		string vals = "(";
		bool outputted = false;

		string[string] columns;
		auto cnames = result.fieldNames;
		foreach(i, col; result.front.toStringArray) {
			bool skipMe = false;
			foreach(skip; columnsToSkip) {
				if(cnames[i] == skip) {
					skipMe = true;
					break;
				}
			}
			if(skipMe)
				continue;

			if(outputted) {
				cols ~= ",";
				vals ~= ",";
			} else
				outputted = true;

			cols ~= cnames[i];

			if(result.columnIsNull[i] && cnames[i] !in columnsToModify)
				vals ~= "NULL";
			else {
				string v = col;
				if(cnames[i] in columnsToModify)
					v = columnsToModify[cnames[i]];

				vals ~= "'" ~ escape(v) ~ "'"; 

			}
		}

		cols ~= ")";
		vals ~= ")";

		sql ~= cols ~ " VALUES " ~ vals;

		query(sql);

		result.popFront;

		return lastInsertId;
	}

	int insert(string table,  string[string] columnsToModify) {
		string sql = "INSERT INTO `" ~ table ~ "` ";

		string cols = "(";
		string vals = "(";
		bool outputted = false;

		string[string] columns;
		foreach(i, col; columnsToModify) 
		{
			if(outputted) {
				cols ~= ",";
				vals ~= ",";
			} 
			else{

				outputted = true;
			}
			cols ~= "`" ~i~ "`";
			vals ~= "'" ~ escape(col) ~ "'"; 

		}

		cols ~= ")";
		vals ~= ")";

		sql ~= cols ~ " VALUES " ~ vals;

		query(sql);
		return lastInsertId;
	}

	///更新
	int update(string table,  string[string] columnsToModify, string[string] whereCondition) {
		import std.array;
		Appender!string sql = appender!string();
		//UPDATE  `sendmsg` SET `used_time` = '%s' WHERE `id` = '%s' LIMIT 1;"
		sql.put("UPDATE  `");
		sql.put(table);
		sql.put("` SET ");
		string[] sets, wheres;
		foreach(i, col; columnsToModify) 
		{
			sets~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		foreach(i, col; whereCondition) 
		{
			wheres~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		sql.put(sets.join(", "));
		if(wheres.length != 0 )
		{
			sql.put(" WHERE ");
			sql.put(wheres.join(" AND "));
		}
		query(sql.data);
		return 1;
	}

	///删除
	int remove(string table,   string[string] whereCondition) {
		import std.array;
		Appender!string sql = appender!string();
		sql.put("DELETE FROM  `");
		sql.put(table);
		sql.put("` ");
		string[] wheres;

		foreach(i, col; whereCondition) 
		{
			wheres~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		if(wheres.length != 0 )
		{
			sql.put(" WHERE ");
			sql.put(wheres.join(" AND "));
		}
		query(sql.data);
		return 1;
	}

	///查询
	//sqlInstance.sqlClient.update("user", ["id"], ["id":"1"], 1);
	ResultSet select(string table,  string[] columnsToSelected, string[string] whereCondition, int limit = 1) {
		import std.array;
		Appender!string sql = appender!string();
		sql.put("SELECT ");
		sql.put(columnsToSelected.join(", "));
		sql.put(" FROM `");
		sql.put(table);
		sql.put("` ");

		string[] wheres;

		foreach(i, col; whereCondition) 
		{
			wheres ~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		if(wheres.length != 0 )
		{
			sql.put(" WHERE ");
			sql.put(wheres.join(" AND "));
		}
		if(limit > 0)
		{
			sql.put(" LIMIT ");

			sql.put(to!string(limit));
		}
		return query(sql.data);
	}

	string escape(string str) {
		ubyte[] buffer = new ubyte[str.length * 2 + 1];
		buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, cast(uint) str.length);

		return cast(string) buffer;
	}

	string escaped(T...)(string sql, T t) {
		static if(t.length > 0) {
			string fixedup;
			int pos = 0;


			void escAndAdd(string str, int q) {
				ubyte[] buffer = new ubyte[str.length * 2 + 1];
				buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, str.length);

				fixedup ~= sql[pos..q] ~ '\'' ~ cast(string) buffer ~ '\'';

			}

			foreach(a; t) {
				int q = sql[pos..$].indexOf("?");
				if(q == -1)
					break;
				q += pos;

				static if(__traits(compiles, t is null)) {
					if(t is null)
						fixedup  ~= sql[pos..q] ~ "NULL";
					else
						escAndAdd(to!string(*a), q);
				} else {
					string str = to!string(a);
					escAndAdd(str, q);
				}

				pos = q+1;
			}

			fixedup ~= sql[pos..$];

			sql = fixedup;

			//writefln("\n\nExecuting sql: %s", sql);
		}

		return sql;
	}


	ResultByDataObject!R queryDataObject(R = DataObject, T...)(string sql, T t) {
		// modify sql for the best data object grabbing
		sql = fixupSqlForDataObjectUse(sql);
		//import std.stdio;
		//writeln(sql);
		auto magic = query(sql, t);
		//writeln("------------------------");
		return ResultByDataObject!R(cast(MySqlResult) magic, this);
	}


	ResultByDataObject!R queryDataObjectWithCustomKeys(R = DataObject, T...)(string[string] keyMapping, string sql, T t) {
		sql = fixupSqlForDataObjectUse(sql, keyMapping);

		auto magic = query(sql, t);
		return ResultByDataObject!R(cast(MySqlResult) magic, this);
	}

	int affectedRows() {
		return cast(int) mysql_affected_rows(mysql);
	}

	override ResultSet queryImpl(string sql, Variant[] args...) {
		import std.stdio;

		//writeln("query before....", sql);
		sql = escapedVariants(this, sql, args);
		//writeln("query after....",sql);

		/*enforceEx!(DatabaseException)(
		  !mysql_query(mysql, toCstring(sql)),
		  error() ~ " :::: " ~ sql);
		 */
		try{
			mysql_query(mysql, toCstring(sql));
		}
		catch(DatabaseException ex)
		{
			std.stdio.writeln( ex.msg, " :::: " , sql);
		}
		//writeln("query tocstring....",toCstring(sql));
		return new MySqlResult(mysql_store_result(mysql), sql);
	}

	private:
	MYSQL* mysql;
}

string escapedVariants(Database db, in string sql, Variant[string] t) {
	if(t.keys.length <= 0 || sql.indexOf("?") == -1) {
		return sql;
	}

	string fixedup;
	int currentStart = 0;
	// FIXME: let's make ?? render as ? so we have some escaping capability
	foreach(int i, dchar c; sql) {
		if(c == '?') {
			fixedup ~= sql[currentStart .. i];

			int idxStart = i + 1;
			int idxLength;

			bool isFirst = true;

			while(idxStart + idxLength < sql.length) {
				char C = sql[idxStart + idxLength];

				if((C >= 'a' && C <= 'z') || (C >= 'A' && C <= 'Z') || C == '_' || (!isFirst && C >= '0' && C <= '9'))
					idxLength++;
				else
					break;

				isFirst = false;
			}

			auto idx = sql[idxStart .. idxStart + idxLength];

			if(idx in t) {
				fixedup ~= toSql(db, t[idx]);
				currentStart = idxStart + idxLength;
			} else {
				// just leave it there, it might be done on another layer
				currentStart = i;
			}
		}
	}

	fixedup ~= sql[currentStart .. $];

	return fixedup;
}

string toSql(Database db, Variant a) {
	auto v = a.peek!(void*);
	if(v && (*v is null))
		return "NULL";
	else {
		string str = to!string(a);
		return '\'' ~ db.escape(str) ~ '\'';
	}

	assert(0);
}

string toSql(string s, Database db) {
	if(s is null)
		return "NULL";
	return '\'' ~ db.escape(s) ~ '\'';
}

string toSql(long s, Database db) {
	return to!string(s);
}

/// Note: ?n params are zero based!
string escapedVariants(Database db, in string sql, Variant[] t) 
{
	// FIXME: let's make ?? render as ? so we have some escaping capability
	// if nothing to escape or nothing to escape with, don't bother
	if(t.length > 0 && sql.indexOf("?") != -1) {
		string fixedup;
		int currentIndex;
		int currentStart = 0;
		foreach(int i, dchar c; sql) {
			if(c == '?') {
				fixedup ~= sql[currentStart .. i];

				int idx = -1;
				currentStart = i + 1;
				if((i + 1) < sql.length) {
					auto n = sql[i + 1];
					if(n >= '0' && n <= '9') {
						currentStart = i + 2;
						idx = n - '0';
					}
				}
				if(idx == -1) {
					idx = currentIndex;
					currentIndex++;
				}

				if(idx < 0 || idx >= t.length)
					throw new Exception("SQL Parameter index is out of bounds: " ~ to!string(idx) ~ " at `"~sql[0 .. i]~"`");

				fixedup ~= toSql(db, t[idx]);
			}
		}

		fixedup ~= sql[currentStart .. $];

		return fixedup;
	}

	return sql;
}

cstring toCstring(string c) {
	return cast(cstring) toStringz(c);
}
string fromCstring(cstring c, size_t len = size_t.max) {
	string ret;
	if(c is null)
		return null;
	if(len == 0)
		return "";
	if(len == size_t.max) {
		auto iterator = c;
		len =0;
		while(*iterator)
		{
			iterator++;

			// note they are both byte pointers, so this is sane
			//len = cast(int) iterator - cast(int) c;
			len++;
		}
		assert(len >= 0);
	}

	ret = cast(string) (c[0 .. len].idup);

	return ret;
}

