-- Note: you need to run this query on the server and database where the deadlock occured
select	object_schema_name(qsq.[object_id]) [schema_name],
		object_name(qsq.[object_id]) [object_name],
		qsq.query_id,
		qst.query_sql_text,
		convert(xml, qsp.query_plan) query_plan_xml,
		rs.execution_type_desc
from	sys.query_store_query_text qst
		join sys.query_store_query qsq
		on qsq.query_text_id = qst.query_text_id
		join sys.query_store_plan qsp
		on qsp.query_id = qsq.query_id
		join sys.query_store_runtime_stats rs
		on rs.plan_id = qsp.plan_id
		join sys.query_store_runtime_stats_interval rsi
		on rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
where qsq.last_compile_batch_sql_handle = <sqlhandle>
	and qsq.last_compile_batch_offset_start = <stmtstart>
	and qsq.last_compile_batch_offset_end = <stmtend>
	and '<deadlock_datetime_in_utc>+00:00' between rsi.start_time and rsi.end_time