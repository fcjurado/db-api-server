/*
 * Copyright (C) 2013 by Domingo Alvarez Duarte <mingodad@gmail.com>
 *
 * Licensed under GPLv3, see http://www.gnu.org/licenses/gpl.html.
 */
 
//cache global to local
local trget = table_rawget;
local trset = table_rawset;
 
local globals = getroottable();
WIN32 <- os.getenv("WINDIR") != null;

local function getAppCodeFolder(){
	if(table_rawget(globals, "jniLog", false)) return "/sdcard/db-api";
	if(table_rawget(globals, "WIN32", false)) return ".";
	return os.getenv("PWD");
}

if(!trget(globals, "APP_CODE_FOLDER", false)) ::APP_CODE_FOLDER <- getAppCodeFolder();

function debugLog(msg)
{
	local fd = file(APP_RUN_FOLDER + "/debug.log", "a");
	fd.write(msg);
	fd.write("\n");
	fd.close();
}
//debugLog("starting sq-server_plugin.nut");

math.srand(os.time());

//local AT_DEV_DBG=true;

//local APP_CODE_FOLDER = sqfs.currentdir();
//local EDIT_MD5_PASSWORD = md5("edit_user:r.dadbiz.es:okdoedit");
//local VIEW_MD5_PASSWORD = md5("view_user:r.dadbiz.es:okdoview");

local _sq_profile_calls_at, _sq_profile_calls, _sq_profile_total, _sq_profile_this,
	_sq_profile_start_time, _sq_profile_end_time;

local function profileReset()
{
	_sq_profile_calls_at = {};
	_sq_profile_calls = {};
	_sq_profile_total = {};
	_sq_profile_this = {};
	_sq_profile_start_time = 0;
	_sq_profile_end_time = 0;
}

profileReset();

local function profileDebughook(event_type,sourcefile,line,funcname)
{
	//local fname = format("%s:%d", funcname ? funcname : "unknown", line);
	local fname = funcname ? funcname : "unknown";
	local srcfile=sourcefile ? sourcefile : "unknown";
	local fname_at = format("%s:%d:%s", fname, line, srcfile);
	//local fname_at = fname + ":" + line + ":" + srcfile;
	switch (event_type) {
		//case 'l': //called every line(that contains some code)
			//::print("LINE line [" + line + "] func [" + fname + "]");
			//::print("file [" + srcfile + "]\n");
		//break;
		case 'c': //called when a function has been called
			//::print("LINE line [" + line + "] func [" + fname + "]");
			//::print("file [" + srcfile + "]\n");
			trset(_sq_profile_calls_at, fname_at, trget(_sq_profile_calls_at, fname_at, 0) + 1);
			trset(_sq_profile_this, fname, os.getmillicount());
		break;
		case 'r': //called when a function returns
			//::print("LINE line [" + line + "] func [" + fname + "]");
			//::print("file [" + srcfile + "]\n");
			local time = os.getmillicount() - trget(_sq_profile_this, fname, 0);
			trset(_sq_profile_total, fname, trget(_sq_profile_total, fname, 0) + time);
			trset(_sq_profile_calls, fname, trget(_sq_profile_calls, fname, 0) + 1);
		break;
	}
}

local function profileStart()
{
	profileReset();
	_sq_profile_start_time = os.getmillicount();
	setdebughook(profileDebughook);
}

local function profileEnd()
{
	setdebughook(null);
	_sq_profile_end_time = os.getmillicount();
}

local function profileDump()
{
	// print the results
	auto function ignoreFuncName(fname)
	{
		return (fname == "profileStart" || fname == "profileEnd" || fname == "profileReset");
	}
	local total_time = (_sq_profile_end_time - _sq_profile_start_time) / 1000.0;
	print(format("Profile info: %.3f seconds", total_time));
	local info_ary = [];
	foreach( fname, time in _sq_profile_total )
	{
		time /= 1000.0;
		if(ignoreFuncName(fname)) continue;
		local relative_time = time / (total_time / 100.0);
		local rt_int = relative_time.tointeger();
		local rt_frac = ((relative_time - rt_int) * 100).tointeger();
		info_ary.append(format("%02d.%02d %% in %.3f seconds after %d calls to %s", rt_int, rt_frac, time, table_rawget(_sq_profile_calls, fname, 0), fname));
	}
	info_ary.sort(@(a,b) a<b ? 1 : (a>b ? -1 : 0));
	foreach(line in info_ary)
	{
		print(line);
	}
	info_ary.clear();
	foreach( fname, count in _sq_profile_calls_at )
	{
		if(ignoreFuncName(fname)) continue;
		info_ary.append(format("%6d\tcalls to %s", count, fname));
	}
	info_ary.sort(@(a,b) a<b ? 1 : (a>b ? -1 : 0));
	foreach(line in info_ary)
	{
		print(line);
	}	
}

local _sq_time_start = 0;

local function sqStartTimer()
{
	_sq_time_start = os.getmillicount();
}

local function sqGetElapsedTimer()
{
	return os.getmillicount() - _sq_time_start;
}

local function sqPrintElapsedTimer()
{
	print(format("Elapsed time %.3f seconds", sqGetElapsedTimer()));
}

class MySMTP  {
	boundary = null;
	smtp_server = null;
	smtp_port = null;
	smtp_user_name = null;
	smtp_user_passw = null;
	smtp_from = null;
	smtp_to = null;
	smtp_subject = null;
	smtp_message = null;
	attachments = null;
	_ssl = null;
	_quite = null;
	_fout = null;
	
	constructor(smtp, port){
		server(smtp, port);
		attachments = [];
		_quite = false;
	}
	function server(smtp, port) {
		smtp_server = smtp; 
		smtp_port = port;
		boundary = "_=_+-mixed-+19JK4720AB04PX483";
		_fout = file("MySMPT.log", "wb");
	}
	function login(user, passw) {
		smtp_user_name = user;
		smtp_user_passw = passw;
	}
	function from(pfrom) {smtp_from = pfrom;}
	function to(pto) {smtp_to = pto; }
	function subject(psubject) {smtp_subject = psubject; }
	function message(pmessage) {smtp_message = pmessage; }
	function attach(fn, mime) {
		attachments.push([fn, mime]);
	}
	function _write(str){
		_ssl.write(str);
		_fout.write(str);
	}
	function _read_line(expected_code){
		local result;
		while (true){
			result = _ssl.read();
			if(type(result) == "integer"){
				if (result < 0){ 
					throw(axtls.get_error(result));
				}
			}
			if(type(result) == "string"){
				//print(result);
				local response_code;
				result.gmatch("^(%d+)", function(m){
						response_code = m.tointeger();
						return false;
					});
				//print("Code check", expected_code, response_code);
				if(!response_code || (expected_code != response_code)){
					throw(format("Response code '%d' not equal to expected '%d'", 
						response_code, expected_code));
				}
				return true;
			}
			os.sleep(10);
		}
	}
	function _write_line(line){
		local end_line = "\r\n";
		local result = _write(line);
		_write(end_line);
		return result;
	}
	function _write_message(msg){
		local end_msg = "\r\n.\r\n";
		local result = _write(msg);
		_write(end_msg);
		return result;
	}
	function _getAttachemt(fn){
		local fd = file(fn, "rb");
		local fc = fd.read(fd.len());
		fd.close();
		return base64.encode(fc);
	}
	function send(){
		local client_sock = socket.tcp();
		client_sock.connect(smtp_server, smtp_port);

		local options = axtls.SSL_SERVER_VERIFY_LATER;
		local ssl_ctx = axtls.ssl_ctx(options, axtls.SSL_DEFAULT_CLNT_SESS);

		_ssl = ssl_ctx.client_new(client_sock.getfd());
		// check the return status
		local res = _ssl.handshake_status();
		if (res != axtls.SSL_OK) throw( axtls.get_error(res));
		
		_read_line(220);
		_write_line("ehlo " + smtp_user_name);
		_read_line(250);
		local credentials = base64.encode(format("\x00%s\x00%s", 
			smtp_user_name, smtp_user_passw));
		//print("credentials", credentials);
		_write_line(format("AUTH PLAIN %s", credentials));
		_read_line(235);
		_write_line(format("mail from: <%s>", smtp_from || smtp_user_name));
		_read_line(250);
		_write_line(format("rcpt to: <%s>", smtp_to));
		_read_line(250);
		_write_line("data");
		_read_line(354);

		local buf = format([==[
From: Some People <%s>
To: Another People <%s>
Subject: %s
]==], smtp_from || smtp_user_name, smtp_to, smtp_subject);
		_write(buf);
		local hasAttachment = attachments.len() > 0;
		if (hasAttachment){
			buf = format([==[
Content-Type: multipart/mixed; boundary="%s"

--%s
Content-Type: text/plain; charset="utf-8" 
Content-Transfer-Encoding: 8bit
]==], boundary, boundary);
			_write(buf);
		}
		buf = format([==[

%s
%s
]==], os.date(), smtp_message);
		_write(buf);
		if (hasAttachment){
			foreach( k,v in attachments) {
				buf = format([==[
--%s
Content-Type: %s; name="%s" 
Content-Transfer-Encoding: base64
Content-Disposition: attachment

%s
]==], boundary, v[1], v[0], _getAttachemt(v[0]));
				_write(buf);
			}
			buf = format("--%s--", boundary);
			_write(buf);
		}
		_write_message("");
		//print("Done !");
		_read_line(250);
		_write_line("quit");
		_read_line(221);
		_ssl.free();
		ssl_ctx.free();
		client_sock.close();
	}
}

function IntToDottedIP( intip )
{
	local octet = [0,0,0,0];
	for(local i=3; i >= 0; --i)
	{
		octet[i] = (intip & 0xFF).tostring();
		intip = intip >> 8;
	}
	return octet.concat(".");
}

if(!table_rawget(globals, "gmFile", false)) ::gmFile <- blob();
if(!table_rawget(globals, "__tplCache", false)) ::__tplCache <- {};

function getTemplate(fname, nocache){
	local mixBase = ::table_rawget(__tplCache, fname, false);
	if (!mixBase || nocache){
		local rfn = format("%s/%s", APP_RUN_FOLDER, fname);
		//debug_print("\n", rfn);
		try {
			//debug_print("\n", sqmix.parsefile(rfn));
			mixBase = sqmix.loadfile(rfn);
		} catch(e){
			debug_print("\n", e);
		}
		::__tplCache[fname] <- mixBase;
	}
	return mixBase;
}

/*
if(!table_rawget(globals, "__stmtCache", false)) ::__stmtCache <- {};
function getCachedStmt(db, stmt_key, sql_or_func){
	local stmt = ::table_rawget(__stmtCache, stmt_key, false);
	if (!stmt){
		//local db =checkCompaniesUkDB()
		local sql;
		if (type(sql_or_func) == "function") sql = sql_or_func();
		else sql = sql_or_func;
		//debug_print("\n", sql);
		stmt = ::db.prepare(sql);
		::__stmtCache.stmt_key <- stmt;
	}
	return stmt;
}
*/

function glob2Sql(v){
	if( v ) {
		v = v.gsub("*", "%%");
		v = v.gsub("%?", "_");
	}
	return v;
}

function unescapeHtml ( str ){
	if (str){
		return str.gsub("(&[^;]-;)", function(m){
				if (m == "&lt;") return "<";
				else if (m == "&gt;") return ">";
				else if (m == "&amp;") return "&";
				else if (m == "&quot;") return "\"";
				else if (m == "&#x27;") return "'";
				else if (m == "&#x2F;") return "/";
				else if (m == "&#x60;") return "`";
				return "??";
			});
	}
}

function escapeHtml ( str ){
	if (str){
		return str.gsub("([<>&'\"/`])", function(m){
				if (m == "<") return "&lt;";
				else if (m == ">") return "&gt;";
				else if (m == "&") return "&amp;";
				else if (m == "\"") return "&quot;";
				else if (m == "'") return "&#x27;";
				else if (m ==  "/") return "&#x2F;";
				else if (m ==  "`") return "&#x60;";
				return "??";
			});
	}
}


function var2json(v){
	switch(type(v)){
		case "string":
			return format("%q", v);
			break;
		case "table":
			local result = [];
			foreach(k2, v2 in v) {
				result.push( format([==["%s":%s]==], k2, var2json(v2)));
			}
			return "{" + result.concat(",") + "}";
			break;
			
		case "array":
			local result = [];
			for(local i=0, len=v.len(); i<len; ++i) {
				result.push(var2json(v[i]));
			}
			return "[" + result.concat(",") + "]";
			break;
			
		case "integer":
		case "float":
			return v.tostring();
			break;

		case "bool":
			return v ? "true" : "false";
			break;

		case "null":
			return "null";
			break;

		default:
			//return "\"" + v.tostring().replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t").replace("\b", "\\b").replace("\f", "\\f") + "\"";
			//debug_print("\n", __LINE__, ":", type(v));
			return format("%q", try_tostring(v));
	}
	return "";
}

function json2var(json) {
	local vm = SlaveVM();
	local slave_func = "getTable";
	
	//debug_print(json, "\n");
	//convert new data from json to squilu table for merge
	vm.compilestring(slave_func, "return " + json);
	local tbl = vm.call(true, slave_func);
	return tbl;
}

function time_stamp(){
	return os.date("!%Y-%m-%d %H:%M:%S");
}

class ObjecIdMaker
{
	_machine_id = null;
	_pid = null;
	_index = null;

	constructor()
	{
		_machine_id =  (math.random() * 0xFFFFFF).tointeger();
		_index = (math.random() * 0xFFFFFF).tointeger();
		_pid = (math.random() * 100000).tointeger() % 0xFFFF;
	}

	function next(tm=null) {
		_index = (_index+1) % 0xFFFFFF;
		return format("%.8x%.6x%.4x%.6x",
			(tm == null) ? os.time() : tm, _machine_id, _pid, _index);
	}

	function createFromTime(tm=null) {	
		return format("%.8x0000000000000000", (tm == null) ? os.time() : tm);
	}

	function getTime(objectId) {
		local p1 = objectId.slice(0, 8);
		return p1.tointeger(16);
	}

	function getDate(objectId) {
		local p1 = objectId.slice(0, 8);
		return os.date("!%Y-%m-%dT%H:%M:%S.000Z", p1.tointeger(16));
	}

	
	function getParts(oid) {
		local tm = oid.slice(0, 8).tointeger(16);
		local m_id = oid.slice(8, 14).tointeger(16);
		local p_id = oid.slice(14, 18).tointeger(16);
		local idx_id = oid.slice(18, 24).tointeger(16);
		return [tm, m_id, p_id, idx_id];
	}

	function createFromParts(oid) {
		return format("%.8x%.6x%.4x%.6x",
			oid[0], oid[1], oid[2], oid[3]);
	}
}

ObjectId <- ObjecIdMaker();

function doSaveTableArrayToFD(ta, fd){
	local function dumpValue(val){
		local vtype = type(val);
		if(vtype == "string") fd.write(format("%q,\n", val));
		else if(vtype == "integer") fd.write(format("%d,\n", val));
		else if(vtype == "float") fd.write(format("%f,\n", val));
		else if(vtype == "bool") fd.write(format("%s,\n", val ? "true" : "false"));
		else if(vtype == "null") fd.write("null,\n");
		else throw format("Only string, integer, float, bool are supported ! (%s)", vtype);
	}
	local tatype = type(ta);
	if(tatype == "table"){
		fd.write("{\n");
		foreach(k,v in ta){
			fd.write(format("[%q] = ", k));
			local vtype = type(v);
			if(vtype == "table" || vtype == "array"){
				doSaveTableArrayToFD(v, fd);
			}
			else
			{
				dumpValue(v);
			}
		}
		fd.write("},\n");
	}
	else if(tatype == "array"){
		fd.write("[\n");		
		foreach(k,v in ta){
			local vtype = type(v);
			if(vtype == "table" || vtype == "array"){
				doSaveTableArrayToFD(v, fd);
			}
			else
			{
				dumpValue(v);
			}
		}
		fd.write("],\n");		
	}
	else throw "Only table/array suported";
}

function doSaveTableArrayToFileName(tbl, fname){
	local fd = file(fname, "w");
	fd.write("return [\n");
	doSaveTableArrayToFD(tbl, fd);
	fd.write("];");
	fd.close();
}

function doLoadTableArrayFromFileName(fname){
	local func = loadfile(fname);
	return func()[0];
}

function fillTemplate(atemplate, data, nocache){
	data.escapeHtml <- escapeHtml;
	local mixFunc =getTemplate(atemplate, nocache);
	mixFunc.call(data);
}

function getFfileName(full_path) {
	return full_path.match("([^/]+)$");
}

//
// Post
//
function split_filename(path){
  local result;
  path.gmatch("[/\\]?([^/\\]+)$", function(m){
	result = m;
	return false;
  });
  return result;
}

function form_url_insert_field (dest, key, value){
  local fld = table_rawget(dest, key, null);
  if (!fld) dest[key] <- value;
  else
  {
	if (type (fld) == "array") fld.push(value);
	else  dest[key] <- [fld, value];
  }
}

function multipart_data_get_field_names(headers, name_value){
  //foreach(k,v in headers) debug_print(k, "::", v, "\n");
  local disp_header = headers["content-disposition"] || "";
  local attrs = {};
  disp_header.gmatch(";%s*([^%s=]+)=\"(.-)\"", function(attr, val) {
	attrs[attr] <- val;
	//debug_print(attr, "::", val, "\n");
	return true;
  });
  name_value.push(attrs.name);
  name_value.push(table_rawget(attrs, "filename", false) ? split_filename(attrs.filename) : null);
}

function multipart_data_break_headers(header_data){
	local headers = {};
	header_data.gmatch("([^%c%s:]+):%s+([^\n]+)", function(type, val){
		headers[type.tolower()] <- val;
		return true;
	});
	return headers;
}

function multipart_data_read_field_headers(input, state){
	local s, e, pos = state.pos;
	input.find_lua("\r\n\r\n", function(start, end){s=start; e=end; return false;}, pos, true);
	if( s ) {
		state.pos <- e;
		return multipart_data_break_headers(input.slice(pos, s));
	}
	else return null;
}

function multipart_data_read_field_contents(input, state){
	local boundaryline = "\r\n" + state.boundary;
	local s, e, pos = state.pos;
	input.find_lua(boundaryline, function(start, end){ s=start; e=end; return false;}, pos, true)
	if (s) {
		state.pos <- e;
		state.size <- s-pos;
		return input.slice(pos, s);
	}
	else {
		state.size <- 0;
		return null;
	}
}

function multipart_data_file_value(file_contents, file_name, file_size, headers){
  local value = { contents = file_contents, name = file_name, size = file_size };
  foreach( h, v in headers) {
	if (h != "content-disposition") value[h] <- v;
  }
  return value;
}

function multipart_data_parse_field(input, state){
	local headers, value;

	headers = multipart_data_read_field_headers(input, state);
	if (headers) {
		local name_value=[];
		multipart_data_get_field_names(headers, name_value);
		if (name_value[1]) { //file_name
			value = multipart_data_read_field_contents(input, state);
			value = multipart_data_file_value(value, name_value[1], state.size, headers);
			name_value[1] = value;
		}
		else name_value[1] = multipart_data_read_field_contents(input, state)
		return name_value;
	}
	return null;
}

function multipart_data_get_boundary(content_type){
	local boundary;
	content_type.gmatch("boundary%=(.-)$", function(m){
		boundary = m;
		return false;
	});
	return "--" + boundary;
}

function parse_multipart_data(input, input_type, tab=null){
	if(!tab) tab = {};
	local state = {};
	state.boundary <- multipart_data_get_boundary(input_type);
	input.find_lua(state.boundary, function(start, end){state.pos <- end+1;return false;}, 0, true);
	while(true){
		local name_value = multipart_data_parse_field(input, state);
		//debug_print("\nparse_multipart_data: ", name_value);
		if(!name_value) break;
		form_url_insert_field(tab, name_value[0], name_value[1]);
	}
	return tab;
}

function parse_qs(qs, tab=null){
	if(!tab) tab = {};
	if (type(qs) == "string") {
		//debug_print(qs)
		qs.gmatch("([^&=]+)=([^&=]*)&?", function(key,val){
			//debug_print(key, "->", val)
			form_url_insert_field(tab, url_decode(key), url_decode(val));
			return true;
		});
	}
	else if (qs) throw("Request error: invalid query string");

	return tab;
}

function parse_qs_to_table(qs, tab=null){
	if(!tab) tab = {};
	if (type(qs) == "string") {
		//debug_print(qs)
		qs.gmatch("([^&=]+)=([^&=]*)&?", function(key,val){
			//debug_print(key, "->", val)
			key = url_decode(key);
			tab[key] <- url_decode(val);
			return true;
		});
	}
	else if (qs) throw("Request error: invalid query string");

	return tab;
}

function parse_qs_to_table_k(qs, tab=null, tabk=null){
	if(!tab) tab = {};
	if(!tabk) tabk = [];
	if (type(qs) == "string") {
		qs.gmatch("([^&=]+)=([^&=]*)&?", function(key, val){
		//debug_print(key, "->", val)
			key = url_decode(key);
			tabk.push(key);
			tab[key] <- url_decode(val);
			return true;
		});
	}
	else if (qs) throw("Request error: invalid query string");
	return tab;
}

function parse_post_data(input_type, data, tab = null){
	if(!tab) tab = {};
	local length = data.len();
	if (input_type.find("x-www-form-urlencoded") >= 0) parse_qs(data, tab);
	else if (input_type.find("multipart/form-data") >= 0) parse_multipart_data(data, input_type, tab);
	else if (input_type.find("SLE") >= 0) {
		local vv = [];
		sle2vecOfvec(data, vv);
		if (vv.len() > 0) {
			local names = vv[0];
			local values = vv[1];
			for (local i=0, len = names.len(); i < len; ++i){
				tab[names[i]] <- values[i];
			}
		}
	}
	return tab;
}

function get_post_data(request, max_len=1024*1000){
	local data_len = (request.get_header("Content-Length") || "0").tointeger();
	//debug_print("\nget_post_fields: ", __LINE__, ":", data_len, ":", max_len);
	if (data_len > 0 && data_len <= max_len) {
		local data = request.read(data_len);
		return data;
	}
	return null;
}

function get_post_fields(request, max_len=1024*1000, post_fields=false){
	local data_len = (request.get_header("Content-Length") || "0").tointeger();
	if(!post_fields) post_fields = {};
	local data = get_post_data(request, max_len);
	if (data) {
		local content_type = request.get_header("Content-Type") || "x-www-form-urlencoded";
		if(content_type.find("application/json") >= 0){
			return data;
		}
		parse_post_data(content_type, data, post_fields);
	}
	return post_fields;
}

local allowedUploadFileExtensions = {
	[".png"] = "image/png",
	[".jpg"] = "image/jpeg",
	[".gif"] = "image/gif",
	[".svg"] = "image/svg+xml",
}

function getMimeType(fname){
	local ext;
	fname.gmatch("(%.?[^%.\\/]*)$", @(m) ext=m);
	if( ext ) return table_rawget(allowedUploadFileExtensions, ext, "unknown");
	return "unknown";
}

function sanitizePath(path){
	//reorient separators
	path=path.gsub("\\", "/");

	//remove relativeness
	local relatpattern = "%.%.+";

	while (path.find_lua(relatpattern) > 0){
		path=path.gsub(relatpattern, "") //something like    /Repositories/swycartographer/res/msys/ + /mod
	}                              //gets converted to /Repositories/swycartographer/res/msys/mod

	//remove possible doubles
	relatpattern = "//";
	while(path.find(relatpattern) >= 0){
		path=path.gsub(relatpattern, "/");
	}

	//remove trailing slash
	if(path.endswith("/")) path=path.slice(0,-2);
	//remove slash at the begining
	if(path.startswith("/")) path = path.slice(1);
	path = path.gsub("[^A-Za-z0-9_%-%./]", "");
	return path
}

local allowedEditFileExtensions = {
	[".nut"] = true,
	[".tpl"] = true,
	[".html"] = true,
	[".css"] = true,
	[".js"] = true,
}

function isExtensionAllowed(fname){
	local ext;
	fname.gmatch("(%.?[^%.\\/]*)$", @(m) ext=m);
	if( ext ) return table_rawget(allowedEditFileExtensions, ext, false);
	return false;
}

function getFilesInPath(path, files=null, prefix=""){
	if(!files) files = [];
	local prefix_len = prefix.len();
	foreach( file in sqfs.dir(path) ){
		if(file != "." && file != ".." ){
			local f = path + "/" + file;
			local pf
			if (prefix_len > 0) pf = prefix + "/" + file;
			else pf = file;

			try {
				local attr = sqfs.attributes (f);

				if(attr.mode == "directory") getFilesInPath (f, files, pf);
				else
				{
					if( isExtensionAllowed(pf) ) files.push(pf);
					//foreach(name, value in attr) print (name, value);
				}
			} catch(e) {}
		}
	}
	files.sort();
	return files;
}

function getDbListFromStmt(stmt, maxSeconds=0){
	local error_code = 0;
	local rows = [];
	local db = stmt.get_db();
	if (maxSeconds){
		//local x = 0
		db.progress_handler(25, function(info) {
			//x = x +1
			//debug_print(x, "\n")
			//debug_print(x, ":", os.difftime(os.time(), info[0]), ":", info[1], "\n")
			if (os.difftime(os.time(), info[1]) > info[0]) return 1;
			return 0;
		}, [maxSeconds, os.time()]);
	}
	else db.progress_handler(null);

	try {
		while (stmt.next_row()){
			rows.push(stmt.asArray());
		}
	} catch(e){
		error_code = db.error_code();
	}

	if (maxSeconds) db.progress_handler(null);
	stmt.reset();
	//debug_print("\n", rows.len(), "\n");
	return [rows, error_code];
}

function strHasContent(v){
	if(v && v.len() > 0) return true;
	return false;
}

function send_http_error_500(request, err_msg){
	if(AT_DEV_DBG) {
		foreach(k,v in get_last_stackinfo()) debug_print("\n", k, ":", v);
		debug_print("\n", err_msg, "\n")
	}
	local response = format("HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: %d\r\n\r\n%s", 
		err_msg.len(),  err_msg);
	request.write(response, response.len());
	return true;
}

/* Leaks memory on reloads !!!!!
local counter_db = SQLite3("file:counter_db?mode=memory&cache=shared");
counter_db.exec_dml("create table if not exists counter(host text primary key not null, counter integer not null);");
local counter_select_stmt = counter_db.prepare("select counter from counter where host= ?");
local counter_insert_stmt = counter_db.prepare("insert into counter(host, counter) values(?, 1)");
local counter_update_stmt = counter_db.prepare("update counter set counter= counter+1 where host=?");
*/

local uri_handlers = {
	["/SQ/hello-world"] = function(request){
		local hello = "Hello World !\n";
		local resp = format("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8;\r\nContent-Length: %d\r\n\r\n%s", hello.len(), hello)
		request.print(resp)
		return true;
	},
	["/SQ/testParams"] = function(request){
		local mFile = gmFile;
		mFile.clear(); //allways reset global vars
		mFile.write("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n\r\n")
		mFile.write("<html><body><h1>Request Info</h1><ul>")
		foreach(k, v in request.info) {
			if ("table" == type(v) ){
				mFile.write(format("<li><b>%s</b>:</li><ul>", k));
				foreach( k2, v2 in v){
					mFile.write(format("<li><b>%s</b>: %s</li>", k2, v2));
				}
				mFile.write("</ul>");
			}
			else mFile.write(format("<li><b>%s</b>: %s</li>", k, (v == NULL ? "" : v).tostring()));
		}
		mFile.write("</ul></body></html>");
		request.write_blob(mFile);
		return true;
	},
	["/SQ/logout"] = function(request){
		request.close_session();
		request.print(format("HTTP/1.1 302 Found\r\nLocation: http%s://%s\r\n\r\n", 
			request.info.is_ssl ? "s" : "", request.info.http_headers.Host))
		return true;
	},
}

function add_uri_hanlders(tbl){
	foreach(k,v in tbl) uri_handlers[k] <- v;
}

local uri_filters = [];

function add_uri_filters(func){
	uri_filters.push(func);
}

function remove_uri_filters(func){
	for(local i=0, len=uri_filters.len(); i < len; ++i){
		if(uri_filters[i] == func) {
			uri_filters.remove(i);
			break;
		}
	}
}

function apply_uri_filters(request){
	for(local i=0, len=uri_filters.len(); i < len; ++i){
		if(uri_filters[i](request)) {
			return true;
		}
	}
	return false;
}

function sendJson(request, response, extra_headers=""){
	request.print(format("HTTP/1.1 200 OK\r\nServer: SquiluAppServer\r\nContent-Type: text/json; charset=utf-8\r\nCache-Control: no-cache\r\nContent-Length: %d\r\n%s\r\n%s", response.len(), extra_headers, response));
	return true;
}

function sendJs(request, response, extra_headers=""){
	request.print(format("HTTP/1.1 200 OK\r\nServer: SquiluAppServer\r\nContent-Type: application/x-javascript; charset=utf-8\r\nCache-Control: no-cache\r\nContent-Length: %d\r\n%s\r\n%s", response.len(), extra_headers, response));
	return true;
}

/*
if(AT_DEV_DBG || !table_rawget(globals, "MyWebAppLoaded", false)) {
	dofile(APP_CODE_FOLDER + "/webapp.nut");
}

if(AT_DEV_DBG || !table_rawget(globals, "WebDBApiLoaded", false)) {
	dofile(APP_CODE_FOLDER + "/db-api-server-html.nut");
}
*/

local ourbiz_password = md5("mingote:ourbiz.dadbiz.es:tr14pink");
function handle_request(request){
	//static content served by mongoose directly
	local request_uri = request.info.uri;
	//debug_print(request.get_option("document_root"), "::", request_uri, "\n")
	/*
	local ext = request_uri.match("%.%w+$");
	switch(ext)
	{
		case ".jpg":
		case ".png":
		case ".svg":
		case ".js":
		case ".css":
		case ".mp4":
		case ".webm":
		case ".ico":
		case ".php":
		case ".html":
			return false;

	}
	*/

	if(apply_uri_filters(request)) {
		return true;
	}
	
	if( table_rawget(uri_handlers, request_uri, false) ) return uri_handlers[request_uri](request);
	return false;
}

if(table_rawin(globals, "addExtraWebAppCode"))
{
	//debugLog("call  addExtraWebAppCode");
	addExtraWebAppCode(this);
}
//debugLog("end of sq-server_plugin.nut");