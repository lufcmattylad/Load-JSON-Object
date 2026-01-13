/*------------------------------------------------------------------------------
 * Author       Stefan Dobre
 * Created      23.04.2019
 *
 * Description  Process Plugin to add a JSON Object to an APEX page already at render time
 *              The Object can be derrived from a SQL Query, PL/SQL Procedure or Static Text
 *              This plugin can be used for example to preload metadata for JS processes
 *
 * License      MIT 
 *------------------------------------------------------------------------------
 * Modification History
 *
 * 24.04.2019  SD v1.0     initial release
 * 12.01.2026  MM v24.2.1  APEX 24.2 compatibility - use CLOB output instead of HTP buffer
                           Support for APEX Binds
                           Extend/merge properties into an existing object rather than replacing it completely.
 */-----------------------------------------------------------------------------

function execute
    ( p_process in apex_plugin.t_process
    , p_plugin  in apex_plugin.t_plugin
    )
return apex_plugin.t_process_exec_result
as
    l_exec_result apex_plugin.t_process_exec_result;

    l_source                  varchar2(4000) := p_process.attribute_01;
    l_sql                     varchar2(4000) := p_process.attribute_02;
    l_json_sql                varchar2(4000) := p_process.attribute_03;
    l_plsql_json              varchar2(4000) := p_process.attribute_04;
    l_static_json             varchar2(4000) := p_process.attribute_05;
    l_javascript_variable     varchar2(4000) := p_process.attribute_06;

    --surrounded by quotes as it will be used a parameter
    l_js_literal              varchar2(4000) := apex_escape.js_literal(l_javascript_variable , '"' );
    
    --not surrounded by quotes, as it will be on the left side of an assignment
    l_js_literal_with_window  varchar2(4000) := apex_escape.js_literal('window.' || l_javascript_variable, null);
    
    l_clob                    clob;
    l_json_clob               clob;
    l_cursor                  sys_refcursor;
    
begin

    apex_plugin_util.debug_process
        ( p_plugin  => p_plugin
        , p_process => p_process
        );

    htp.p('<script>');
    
    /* wrapping the javascript in a self calling function
     * this helps not pollute the global namespace
     */
    htp.p('(function(){');
    
    /*
     * if we include this function in its own file 
     * or through apex_javascript.add_inline_code/ add_onload_code
     * it gets added at the end of the html file, but I already
     * want to use it now, so the regions and possibly included script tags
     * can already access the json object
     */ 
    htp.p('var createNestedObject=function(e,t){for(var r=(t=t.split(".")).length-1,a=0;a<r;++a){var n=t[a];n in e||(e[n]={}),e=e[n]}};');
    
    --creating the (possibly nested) object and sticking it onto the window object
    htp.p('createNestedObject(window, ' || l_js_literal || ');');

    -- New behavior: merge properties using Object.assign
    -- Initialize to empty object if undefined, then merge
    htp.prn(l_js_literal_with_window || ' = ' || l_js_literal_with_window || ' || {}; ');
    htp.prn('Object.assign(' || l_js_literal_with_window || ', ');

    --depending on the source, the actual json, not escaped will be htp.p'ed
    case l_source
        when 'sql' then
            /* Use APEX_EXEC to support APEX bind variables
            * APEX_EXEC automatically binds page and application items
            */
            declare
                l_context apex_exec.t_context;
            begin
                -- Open query context with automatic APEX item binding
                l_context := apex_exec.open_query_context(
                    p_location          => apex_exec.c_location_local_db,
                    p_sql_query         => l_sql,
                    p_auto_bind_items   => true
                );
                
                -- Initialize JSON output
                apex_json.initialize_clob_output(p_indent => 0);
                
                -- Use write_context (not write) for apex_exec context
                apex_json.open_array;
                apex_json.write_context(l_context);
                apex_json.close_array;
                
                -- Close the context
                apex_exec.close(l_context);
                
                -- Get the JSON output
                l_json_clob := apex_json.get_clob_output;
                apex_json.free_output;
                
                apex_util.prn( p_clob => l_json_clob, p_escape => false );
                
            exception
                when others then
                    apex_exec.close(l_context);
                    apex_json.free_output;
                    raise;
            end;

        when 'jsonsql' then
            declare
                l_column_value_list apex_plugin_util.t_column_value_list;
            begin
                l_column_value_list := apex_plugin_util.get_data(
                    p_sql_statement  => l_json_sql,
                    p_min_columns    => 1,
                    p_max_columns    => 1,
                    p_component_name => p_process.name
                );
                
                -- Extract value from first column, first row
                -- Works for both VARCHAR2 and CLOB sources
                if l_column_value_list.exists(1) and l_column_value_list(1).count > 0 then
                    l_clob := l_column_value_list(1)(1);
                    apex_util.prn( p_clob => l_clob, p_escape => false );
                end if;
            end;
            
        when 'plsql' then
            /* in case of PL/SQL, the developer is expected to use 
             * apex_json.open_object/ write, etc
             * Instead of writing to HTP, write to CLOB output
             * apex_plugin_util.execute_plsql_code handles APEX bind variables
             */
            apex_json.initialize_clob_output(p_indent => 0);
            apex_plugin_util.execute_plsql_code( p_plsql_code => l_plsql_json );
            
            l_json_clob := apex_json.get_clob_output;
            apex_json.free_output;
            
            apex_util.prn( p_clob => l_json_clob, p_escape => false );
            
        when 'static' then
            /* The developer can also provide a JSON as plain text
             */
            apex_util.prn( p_clob => l_static_json, p_escape => false );
    end case;
    
    -- Close the Object.assign call
    htp.p(');'); -- Close Object.assign
    
    --closing the self calling function
    htp.p('})();');
    
    htp.p('</script>');

    return l_exec_result;
end;
