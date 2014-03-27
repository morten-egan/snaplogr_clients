create or replace package body snaplogr

as

	snaplogr_url						varchar2(4000) := 'http://www.codemonth.dk/s/';
	snaplogr_set_id						varchar2(4000) := 'none';
	snap_content						json;

	type allstats is record (
		start_time							date
		, middle_time						date
		, end_time							date
	);

	rrun									allstats;

	procedure snapit
	
	as

		no_id_set							exception;
		pragma 								exception_init(no_id_set, -20001);

		snaplogr_req						utl_http.req;
		snaplogr_res						utl_http.resp;
		snaplogr_res_text					varchar2(4000);

		snap_text							varchar2(32000) := 'snap_content=';
	
	begin
	
		dbms_application_info.set_action('snapit');

		if snaplogr_set_id != 'none' and snaplogr_set_id is not null then
			snap_content.put('id', snaplogr_set_id);

			snap_text := snap_text || snap_content.to_char;

			-- We have set id and let us ship the snap to snaplogr
			utl_http.set_response_error_check(
				enable => true
			);
			utl_http.set_detailed_excp_support(
				enable => true
			);

			snaplogr_req := utl_http.begin_request(
				url => snaplogr_url || 'snaplogr_ui.snap'
				, method => 'POST'
			);

			utl_http.set_header(
				r => snaplogr_req
				, name => 'User-Agent'
				, value => 'SNAPLOGR'
			);

			utl_http.set_header(
				r => snaplogr_req
				, name => 'Content-Type'
				, value => 'application/x-www-form-urlencoded'
			);

			utl_http.set_header(
				r => snaplogr_req
				, name => 'Content-Length'
				, value => length(snap_text)
			);

			-- Write the content
			utl_http.write_text (
				r => snaplogr_req
				, data => snap_text
			);

			snaplogr_res := utl_http.get_response (
				r => snaplogr_req
			);

			if snaplogr_res.status_code != 200 then
				raise_application_error(-20001, 'Could not parse snap packet.');
			end if;

			utl_http.read_text (
				r => snaplogr_res
				, data => snaplogr_res_text
			);

			utl_http.end_response(
				r => snaplogr_res
			);
		else
			raise_application_error(-20001, 'Snaplogr ID not set for session');
		end if;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end snapit;

	procedure setup (
		snaplogr_user						in				varchar2
		, snaplogr_pass						in				varchar2
	)
	
	as

		extracted_client_id					varchar2(4000);
		no_contact							exception;
		pragma 								exception_init(no_contact, -20001);
	
	begin
	
		dbms_application_info.set_action('setup');

		select utl_http.request(snaplogr_url || 'snaplogr_ui.snaplogr_session_id?username=' || snaplogr_user || '&pass=' || snaplogr_pass)
		into extracted_client_id
		from dual;

		if extracted_client_id = 'none' then
			raise_application_error(-20001, 'Unknown login');
		else
			snaplogr_set_id := replace(replace(extracted_client_id, chr(10)), chr(13));
		end if;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end setup;

	procedure log (
		logstring					in				varchar2
	)
	
	as
	
	begin
	
		dbms_application_info.set_action('log');

		snap_content := json();

		snap_content.put('type', 1);
		snap_content.put('content', logstring);

		snapit;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end log;

	procedure sr
	
	as
	
	begin
	
		dbms_application_info.set_action('sr');

		rrun.start_time := sysdate;
		rrun.middle_time := null;
		rrun.end_time := null;

		delete from run_stats;

    	insert into run_stats 
    	select 'before', stats.* from stats;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end sr;

	procedure mr
	
	as
	
	begin
	
		dbms_application_info.set_action('mr');

		if rrun.middle_time is null and rrun.start_time is not null then
			rrun.middle_time := sysdate;
			insert into run_stats 
    		select 'after 1', stats.* from stats;
		end if;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end mr;

	procedure er (
		stop_val						in				number default 500
	)
	
	as

		content_json					json := json();
		stat_list						json_list := json_list();
		stat_json						json := json();

		cursor get_stats is
			select 
				a.name 
            	, b.value-a.value as run1
            	, c.value-b.value as run2
            	, ( (c.value-b.value)-(b.value-a.value)) as diff
        	from 
        		run_stats a
        		, run_stats b
        		, run_stats c
    		where 
    			a.name = b.name
			and 
				b.name = c.name
			and 
				a.runid = 'before'
			and 
         		b.runid = 'after 1'
			and 
				c.runid = 'after 2'
			and 
				abs( (c.value-b.value) - (b.value-a.value) ) > stop_val
			order by 
				abs( (c.value-b.value)-(b.value-a.value));
	
	begin
	
		dbms_application_info.set_action('er');

		if rrun.end_time is null and rrun.middle_time is not null and rrun.start_time is not null then
			rrun.end_time := sysdate;
			insert into run_stats 
    		select 'after 2', stats.* from stats;

			-- Close run, create json, filter vals and ship call
			snap_content := json();
			snap_content.put('type', 4);
			content_json.put('start', to_char(rrun.start_time, 'YYYY-MM-DD') || 'T' || to_char(rrun.start_time, 'HH24:MI:SS'));
			content_json.put('middle', to_char(rrun.middle_time, 'YYYY-MM-DD') || 'T' || to_char(rrun.middle_time, 'HH24:MI:SS'));
			content_json.put('end', to_char(rrun.end_time, 'YYYY-MM-DD') || 'T' || to_char(rrun.end_time, 'HH24:MI:SS'));
			for i in get_stats loop
				stat_json.put('statname', i.name);
				stat_json.put('start', i.run1);
				stat_json.put('middle', i.diff);
				stat_json.put('end', i.run2);
				stat_list.append(stat_json.to_json_value);
				stat_json := json();
			end loop;
			content_json.put('runstats', stat_list);

			snap_content.put('content', content_json);

			snapit;
		end if;

		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end er;

begin

	dbms_application_info.set_client_info('snaplogr');
	dbms_session.set_identifier('snaplogr');

end snaplogr;
/