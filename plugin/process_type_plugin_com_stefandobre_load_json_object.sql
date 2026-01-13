prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- Oracle APEX export file
--
-- You should run this script using a SQL client connected to the database as
-- the owner (parsing schema) of the application or as a database user with the
-- APEX_ADMINISTRATOR_ROLE role.
--
-- This export file has been automatically generated. Modifying this file is not
-- supported by Oracle and can lead to unexpected application and/or instance
-- behavior now or in the future.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_imp.import_begin (
 p_version_yyyy_mm_dd=>'2024.11.30'
,p_release=>'24.2.11'
,p_default_workspace_id=>8205260902819239028
,p_default_application_id=>158053
,p_default_id_offset=>0
,p_default_owner=>'LUFCMATTYLAD'
);
end;
/
 
prompt APPLICATION 158053 - 🌶️
--
-- Application Export:
--   Application:     158053
--   Name:            🌶️
--   Date and Time:   11:00 Tuesday January 13, 2026
--   Exported By:     MATT@GIZMA.COM
--   Flashback:       0
--   Export Type:     Component Export
--   Manifest
--     PLUGIN: 127823905510244443729
--   Manifest End
--   Version:         24.2.11
--   Instance ID:     63113759365424
--

begin
  -- replace components
  wwv_flow_imp.g_mode := 'REPLACE';
end;
/
prompt --application/shared_components/plugins/process_type/com_stefandobre_load_json_object
begin
wwv_flow_imp_shared.create_plugin(
 p_id=>wwv_flow_imp.id(127823905510244443729)
,p_plugin_type=>'PROCESS TYPE'
,p_name=>'COM.STEFANDOBRE.LOAD_JSON_OBJECT'
,p_display_name=>'Load JSON Object'
,p_supported_component_types=>'APEX_APPLICATION_PAGE_PROC'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'/*------------------------------------------------------------------------------',
' * Author       Stefan Dobre',
' * Created      23.04.2019',
' *',
' * Description  Process Plugin to add a JSON Object to an APEX page already at render time',
' *              The Object can be derrived from a SQL Query, PL/SQL Procedure or Static Text',
' *              This plugin can be used for example to preload metadata for JS processes',
' *',
' * License      MIT ',
' *------------------------------------------------------------------------------',
' * Modification History',
' *',
' * 24.04.2019  SD v1.0     initial release',
' * 12.01.2026  MM v24.2.1  APEX 24.2 compatibility - use CLOB output instead of HTP buffer',
'                           Support for APEX Binds',
'                           Extend/merge properties into an existing object rather than replacing it completely.',
' */-----------------------------------------------------------------------------',
'',
'function execute',
'    ( p_process in apex_plugin.t_process',
'    , p_plugin  in apex_plugin.t_plugin',
'    )',
'return apex_plugin.t_process_exec_result',
'as',
'    l_exec_result apex_plugin.t_process_exec_result;',
'',
'    l_source                  varchar2(4000) := p_process.attribute_01;',
'    l_sql                     varchar2(4000) := p_process.attribute_02;',
'    l_json_sql                varchar2(4000) := p_process.attribute_03;',
'    l_plsql_json              varchar2(4000) := p_process.attribute_04;',
'    l_static_json             varchar2(4000) := p_process.attribute_05;',
'    l_javascript_variable     varchar2(4000) := p_process.attribute_06;',
'',
'    --surrounded by quotes as it will be used a parameter',
'    l_js_literal              varchar2(4000) := apex_escape.js_literal(l_javascript_variable , ''"'' );',
'    ',
'    --not surrounded by quotes, as it will be on the left side of an assignment',
'    l_js_literal_with_window  varchar2(4000) := apex_escape.js_literal(''window.'' || l_javascript_variable, null);',
'    ',
'    l_clob                    clob;',
'    l_json_clob               clob;',
'    l_cursor                  sys_refcursor;',
'    ',
'begin',
'',
'    apex_plugin_util.debug_process',
'        ( p_plugin  => p_plugin',
'        , p_process => p_process',
'        );',
'',
'    htp.p(''<script>'');',
'    ',
'    /* wrapping the javascript in a self calling function',
'     * this helps not pollute the global namespace',
'     */',
'    htp.p(''(function(){'');',
'    ',
'    /*',
'     * if we include this function in its own file ',
'     * or through apex_javascript.add_inline_code/ add_onload_code',
'     * it gets added at the end of the html file, but I already',
'     * want to use it now, so the regions and possibly included script tags',
'     * can already access the json object',
'     */ ',
'    htp.p(''var createNestedObject=function(e,t){for(var r=(t=t.split(".")).length-1,a=0;a<r;++a){var n=t[a];n in e||(e[n]={}),e=e[n]}};'');',
'    ',
'    --creating the (possibly nested) object and sticking it onto the window object',
'    htp.p(''createNestedObject(window, '' || l_js_literal || '');'');',
'',
'    -- New behavior: merge properties using Object.assign',
'    -- Initialize to empty object if undefined, then merge',
'    htp.prn(l_js_literal_with_window || '' = '' || l_js_literal_with_window || '' || {}; '');',
'    htp.prn(''Object.assign('' || l_js_literal_with_window || '', '');',
'',
'    --depending on the source, the actual json, not escaped will be htp.p''ed',
'    case l_source',
'        when ''sql'' then',
'            /* Use APEX_EXEC to support APEX bind variables',
'            * APEX_EXEC automatically binds page and application items',
'            */',
'            declare',
'                l_context apex_exec.t_context;',
'            begin',
'                -- Open query context with automatic APEX item binding',
'                l_context := apex_exec.open_query_context(',
'                    p_location          => apex_exec.c_location_local_db,',
'                    p_sql_query         => l_sql,',
'                    p_auto_bind_items   => true',
'                );',
'                ',
'                -- Initialize JSON output',
'                apex_json.initialize_clob_output(p_indent => 0);',
'                ',
'                -- Use write_context (not write) for apex_exec context',
'                apex_json.open_array;',
'                apex_json.write_context(l_context);',
'                apex_json.close_array;',
'                ',
'                -- Close the context',
'                apex_exec.close(l_context);',
'                ',
'                -- Get the JSON output',
'                l_json_clob := apex_json.get_clob_output;',
'                apex_json.free_output;',
'                ',
'                apex_util.prn( p_clob => l_json_clob, p_escape => false );',
'                ',
'            exception',
'                when others then',
'                    apex_exec.close(l_context);',
'                    apex_json.free_output;',
'                    raise;',
'            end;',
'',
'        when ''jsonsql'' then',
'            declare',
'                l_column_value_list apex_plugin_util.t_column_value_list;',
'            begin',
'                l_column_value_list := apex_plugin_util.get_data(',
'                    p_sql_statement  => l_json_sql,',
'                    p_min_columns    => 1,',
'                    p_max_columns    => 1,',
'                    p_component_name => p_process.name',
'                );',
'                ',
'                -- Extract value from first column, first row',
'                -- Works for both VARCHAR2 and CLOB sources',
'                if l_column_value_list.exists(1) and l_column_value_list(1).count > 0 then',
'                    l_clob := l_column_value_list(1)(1);',
'                    apex_util.prn( p_clob => l_clob, p_escape => false );',
'                end if;',
'            end;',
'            ',
'        when ''plsql'' then',
'            /* in case of PL/SQL, the developer is expected to use ',
'             * apex_json.open_object/ write, etc',
'             * Instead of writing to HTP, write to CLOB output',
'             * apex_plugin_util.execute_plsql_code handles APEX bind variables',
'             */',
'            apex_json.initialize_clob_output(p_indent => 0);',
'            apex_plugin_util.execute_plsql_code( p_plsql_code => l_plsql_json );',
'            ',
'            l_json_clob := apex_json.get_clob_output;',
'            apex_json.free_output;',
'            ',
'            apex_util.prn( p_clob => l_json_clob, p_escape => false );',
'            ',
'        when ''static'' then',
'            /* The developer can also provide a JSON as plain text',
'             */',
'            apex_util.prn( p_clob => l_static_json, p_escape => false );',
'    end case;',
'    ',
'    -- Close the Object.assign call',
'    htp.p('');''); -- Close Object.assign',
'    ',
'    --closing the self calling function',
'    htp.p(''})();'');',
'    ',
'    htp.p(''</script>'');',
'',
'    return l_exec_result;',
'end;',
''))
,p_api_version=>1
,p_execution_function=>'execute'
,p_substitute_attributes=>true
,p_version_scn=>15695039441204
,p_subscribe_plugin_settings=>true
,p_help_text=>'<p>Loads a JSON Object into the page already at render time.</p>'
,p_version_identifier=>'24.2.1'
,p_about_url=>'https://github.com/stefandobre/Load-JSON-Object'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(127823908861704474996)
,p_plugin_id=>wwv_flow_imp.id(127823905510244443729)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Source'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'sql'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'<p>Specify the source of the JSON Object</p>'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(127823909420507476428)
,p_plugin_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_display_sequence=>10
,p_display_value=>'SQL Query'
,p_return_value=>'sql'
,p_help_text=>'<p>A regular SQL Query. Note that values over 4000 characters in length will be cut off at 4000.</p>'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(127800673383200844229)
,p_plugin_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_display_sequence=>20
,p_display_value=>'SQL Query Returning JSON Object'
,p_return_value=>'jsonsql'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>A SQL Query which returns a JSON Object. It can either be fetched from the database, or be built dynamically.</p>',
'<p>The query must return exactly 1 column and 1 one row.</p>'))
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(127823909852617479371)
,p_plugin_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_display_sequence=>30
,p_display_value=>'PL/SQL Procedure'
,p_return_value=>'plsql'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>Choose "PL/SQL Procedure" if you wish to build the JSON Object in a procedural manner.</p>',
'<p>You can use the <code>apex_json</code> package to build the object.</p>'))
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(127823911961345637367)
,p_plugin_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_display_sequence=>40
,p_display_value=>'Static'
,p_return_value=>'static'
,p_help_text=>'<p>A JSON Object as plain text.</p>'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(127823910236372491537)
,p_plugin_id=>wwv_flow_imp.id(127823905510244443729)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'SQL Query'
,p_attribute_type=>'SQL'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'sql'
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<pre>select * from emp</pre> ',
'',
'<p>will be translated into the following JSON Object:</p>',
'',
'<pre>',
'{"row":[',
'{"EMPNO":7369,"ENAME":"SMITH","JOB":"CLERK","MGR":7902,"HIREDATE":"17-DEC-80","SAL":800,"COMM":"","DEPTNO":20},',
'{"EMPNO":7499,"ENAME":"ALLEN","JOB":"SALESMAN","MGR":7698,"HIREDATE":"20-FEB-81","SAL":1600,"COMM":300,"DEPTNO":30},',
'{"EMPNO":7521,"ENAME":"WARD","JOB":"SALESMAN","MGR":7698,"HIREDATE":"22-FEB-81","SAL":1250,"COMM":500,"DEPTNO":30},',
'... ',
']}</pre>',
'',
'<p>To then filter for a specific record, you can use something like:</p>',
'',
'<pre>var record = objectName.row.filter(function(row){return row.ENAME == ''BLAKE''})[0];</pre>'))
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>This is the easiest way to create a JSON Object based on a table.</p>',
'<p>The resulting rows can be accessed via <code>objectName.row[0]<code>, <code>.row[1]</code>, etc.</p>',
'<h3><b>Notes</b></h3>',
'<ul>',
'<li>This is not the most proper way to create a JSON object. Consider using SQL Query Returning JSON Object or PL/SQL Procedure for more control.</li>',
'<li>Values over 4000 characters in length will get cut off at 4000. Use the aforementioned options to circumvent this.</li>',
'</ul>'))
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(127800673799198855796)
,p_plugin_id=>wwv_flow_imp.id(127823905510244443729)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'SQL Query'
,p_attribute_type=>'SQL'
,p_is_required=>true
,p_sql_min_column_count=>1
,p_sql_max_column_count=>1
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'jsonsql'
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>',
'    <h3>Example 1</h3>',
'',
'    <p>The function <code>json_object</code> converts the data to an object. You can use it to have more flexibility in terms of renaming columns, generating nested objects, etc.</p>',
'    <p>Using it on its own, the query would return a row for each object. We have to therefore wrap it in a <code>json_arrayagg</code> function to convert it into a one row array.</p>',
'',
'    <pre>',
'select json_arrayagg(',
'           json_object( ''id''       value empno',
'                      , ''name''     value ename',
'                      , ''pay''      value sal',
'                      )',
'       ) as employees',
'  from emp</pre>',
'',
'    <p>will result in:</p>',
'',
'    <pre>',
'[',
' {"id":7369, "name":"SMITH",  "pay":800 },',
' {"id":7499, "name":"ALLEN",  "pay":1600},',
' {"id":7521, "name":"WARD",   "pay":1250},',
' {"id":7566, "name":"JONES",  "pay":2975},',
' {"id":7654, "name":"MARTIN", "pay":1250},',
' {"id":7698, "name":"BLAKE",  "pay":2850},',
' {"id":7782, "name":"CLARK",  "pay":2450},',
' {"id":7788, "name":"SCOTT",  "pay":3000},',
' {"id":7839, "name":"KING",   "pay":5000},',
' {"id":7844, "name":"TURNER", "pay":1500},',
' {"id":7876, "name":"ADAMS",  "pay":1100},',
' {"id":7900, "name":"JAMES",  "pay":950 },',
' {"id":7902, "name":"FORD",   "pay":3000},',
' {"id":7934, "name":"MILLER", "pay":1300}',
']</pre>',
'',
'    <h3>Example 2</h3>',
'',
'    <p>Here we generate a simple key value pair object. Instead of combining the rows into an array, we can use <code>json_objectagg</code> to merge the rows into 1 object, as the keys in this case are always unique.</p>',
'',
'    <pre>',
'select json_objectagg(dname value deptno) ',
'  from dept</pre>',
'',
'    <p>will result in:</p>',
'',
'    <pre>{"ACCOUNTING":10,"RESEARCH":20,"SALES":30,"OPERATIONS":40}</pre>',
'',
'    <h3>Example 3</h3>',
'',
'    <p>A more complex example which will list all departments and the employees assigned to them.</p>',
'',
'    <pre>',
'select json_arrayagg(',
'        json_object',
'            ( ''department_name'' value d.dname',
'            , ''department_no''   value d.deptno',
'            , ''employees''       value (',
'                select json_arrayagg (',
'                    json_object',
'                        ( ''employee_number'' value e.empno',
'                        , ''employee_name''   value e.ename',
'                        )',
'                )',
'                 from emp e',
'                where e.deptno = d.deptno',
'              )',
'           )',
'      ) as departments',
' from dept d</pre>',
'',
'    <p>will result in:</p>',
'',
'    <pre>',
'[  ',
'{"department_name":"ACCOUNTING","department_no":10,"employees":[  ',
'      {"employee_number":7782, "employee_name":"CLARK"},',
'      {"employee_number":7839, "employee_name":"KING"},',
'      {"employee_number":7934, "employee_name":"MILLER"}',
'    ]},',
'{"department_name":"RESEARCH", "department_no":20,"employees":[  ',
'      {"employee_number":7369, "employee_name":"SMITH"},',
'      {"employee_number":7566, "employee_name":"JONES"},',
'      {"employee_number":7788, "employee_name":"SCOTT"},',
'      {"employee_number":7876, "employee_name":"ADAMS"},',
'      {"employee_number":7902, "employee_name":"FORD"}',
'    ]},',
'{"department_name":"SALES", "department_no":30, "employees":[  ',
'      {"employee_number":7499, "employee_name":"ALLEN"},',
'      {"employee_number":7521, "employee_name":"WARD"},',
'      {"employee_number":7654, "employee_name":"MARTIN"},',
'      {"employee_number":7698, "employee_name":"BLAKE"},',
'      {"employee_number":7844, "employee_name":"TURNER"},',
'      {"employee_number":7900, "employee_name":"JAMES"}',
'    ]},',
'{"department_name":"OPERATIONS", "department_no":40, "employees":null}',
']</pre>',
'',
'</p>'))
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>The SQL Query must return a 1 column/ 1 row result set, populated with a JSON Object.</p>',
'<p>The JSON Object can either be fetched from a JSON column in a table, or dynamically created using <code>json_object</code>, <code>json_array</code>, etc function calls.</p>',
'<p>This method lets you have much more control over the format of the object, and can handle CLOBs.</p>'))
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(127823910807796494588)
,p_plugin_id=>wwv_flow_imp.id(127823905510244443729)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'PL/SQL Code'
,p_attribute_type=>'PLSQL'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'plsql'
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>Example courtesy of oracle-base.com</p>',
'<pre>',
'declare',
'  l_deptno   dept.deptno%TYPE := 10;',
'  l_dept_row dept%ROWTYPE;',
'begin',
'  ',
'  apex_json.open_object; -- {',
'',
'  select d.*',
'    into l_dept_row',
'    from dept d',
'   where d.deptno = l_deptno;',
'',
'  apex_json.open_object(''department''); -- department {',
'  apex_json.write(''department_number'', l_dept_row.deptno);',
'  apex_json.write(''department_name'', l_dept_row.dname);',
' ',
'  apex_json.open_array(''employees''); -- employees: [',
'  ',
'  for cur_rec in (select * from emp e where e.deptno = l_deptno)',
'  loop',
'    apex_json.open_object; -- {',
'    apex_json.write(''employee_number'', cur_rec.empno);',
'    apex_json.write(''employee_name'', cur_rec.ename);',
'    apex_json.close_object; -- } employee',
'  end loop;',
'',
'  apex_json.close_array; -- ] employees',
'  apex_json.close_object; -- } department',
'',
'  apex_json.open_object(''metadata''); -- metadata {',
'  apex_json.write(''published_date'', to_char(sysdate, ''DD-MON-YYYY''));',
'  apex_json.write(''publisher'', ''oracle-base.com'');',
'  apex_json.close_object; -- } metadata ',
'  ',
'  apex_json.close_object; -- }',
'',
'end;</pre>',
'',
'<p>will output the following object:</p>',
'',
'<pre>',
'{',
'"department":{"department_number":10,"department_name":"ACCOUNTING",',
'    "employees":[',
'        {"employee_number":7782,"employee_name":"CLARK"},',
'        {"employee_number":7839,"employee_name":"KING"},',
'        {"employee_number":7934,"employee_name":"MILLER"}',
'    ]},',
'"metadata":{"published_date":"24-APR-2019","publisher":"oracle-base.com"}',
'}',
'</pre>'))
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>Here you can build the JSON Object dynamically using for example the <code>APEX_JSON</code> package.',
'<p>Calls to <code>APEX_JSON</code> procedures internally output to the http buffer, so there is nothing to manually print or return.</p>',
'<p>You can use this method if the JSON Object is impossible or too complicated to create in pure SQL.</p>'))
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(127823912366697644258)
,p_plugin_id=>wwv_flow_imp.id(127823905510244443729)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'JSON Object'
,p_attribute_type=>'TEXTAREA'
,p_is_required=>true
,p_is_translatable=>false
,p_depending_on_attribute_id=>wwv_flow_imp.id(127823908861704474996)
,p_depending_on_has_to_exist=>true
,p_depending_on_condition_type=>'EQUALS'
,p_depending_on_expression=>'static'
,p_examples=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<pre>',
'{"empNo": 7839, "ename": "Blake", "departments": ["Accounting", "Research", "Sales"]}',
'</pre>'))
,p_help_text=>'<p>Provide the JSON Object as plain text, but still well formatted.</p>'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(127800662207515497972)
,p_plugin_id=>wwv_flow_imp.id(127823905510244443729)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Load Into'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'<p>If you specify for example <code>myApp.data</code>, the object will be accesible via <code>myApp.data</code> and <code>window.myApp.data</code> in any JavaScript context, e.g Execute JavaScript Code dynamic actions.</p>'
,p_help_text=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<p>The JavaScript variable path the JSON object will be loaded into.</p>',
'<p>If the variable is nested, it will be created if it does not exist.</p>'))
);
end;
/
prompt --application/end_environment
begin
wwv_flow_imp.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false)
);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
