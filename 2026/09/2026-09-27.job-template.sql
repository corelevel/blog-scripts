use msdb
go
declare @ReturnCode int = 0
declare @step_id int, @schedule_id int, @jobId binary(16)
declare @job_name sysname = N'Make SQL Server busy'
declare @description nvarchar(512) = N'An explanatory and beautifully written description goes here'
declare @category_name sysname = N'[Uncategorized (Local)]'
declare @notify_email_operator_name sysname = 'NeverSleepDBA'
declare @owner_login_name sysname = 'sa'
declare @enabled tinyint = 1

begin transaction

if not exists (select 1 from dbo.syscategories where [name]=@category_name and category_class=1)
begin
	exec @ReturnCode = dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=@category_name
	if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback
end

-- check if job already exists
select	@jobId = job_id
from	dbo.sysjobs
where [name] = @job_name

if @jobId is null
begin
	exec @ReturnCode = dbo.sp_add_job @job_name=@job_name,
		@enabled=@enabled,
		@notify_level_eventlog=0,
		@notify_level_email=2,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=@description,
		@category_name=@category_name,
		@owner_login_name=@owner_login_name,
		@notify_email_operator_name=@notify_email_operator_name,
		@job_id = @jobId output
	if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback

	exec @ReturnCode = dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
	if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback
end
else
begin
	exec @ReturnCode = dbo.sp_update_job @job_id = @jobId,
		@enabled=@enabled,
		@description=@description,
		@category_name=@category_name,
		@owner_login_name=@owner_login_name,
		@notify_email_operator_name=@notify_email_operator_name
	if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback
end

-- delete existing steps
while exists (select 1 from dbo.sysjobsteps where job_id = @jobId)
begin
	select top 1 @step_id = step_id
	from	dbo.sysjobsteps js
	where job_id = @jobId
	order by step_id desc

	exec @ReturnCode = dbo.sp_delete_jobstep @job_name = @job_name, @step_id = @step_id
	if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback
end
-- delete existing schedules
while exists (select 1 from dbo.sysjobschedules where job_id = @jobId)
begin
	select top 1 @schedule_id = schedule_id
	from	dbo.sysjobschedules
	where job_id = @jobId

	exec @ReturnCode = dbo.sp_delete_schedule @schedule_id = @schedule_id, @force_delete = 1
	if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback
end

-- check if primary
exec @ReturnCode = dbo.sp_add_jobstep @job_id=@jobId,
	@step_name=N'IsPrimary',
	@step_id=1,
	@cmdexec_success_code=0,
	@on_success_action=3,
	@on_success_step_id=0,
	@on_fail_action=1,
	@on_fail_step_id=0,
	@retry_attempts=0,
	@retry_interval=0,
	@os_run_priority=0, @subsystem=N'TSQL',
	@command=N'if sys.fn_hadr_is_primary_replica(''StackOverflow2013'') = 0
begin
	raiserror (''I''''m secondary :('', 16, 1)
end',
		@database_name=N'master',
		@flags=0
if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback

-- adding step(s)
exec @ReturnCode = dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'S1', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'print ''S1''', 
		@database_name=N'StackOverflow2013', 
		@flags=0
if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback

exec @ReturnCode = dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'S2', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'print ''S2''', 
		@database_name=N'StackOverflow2013', 
		@flags=0
if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback

exec @ReturnCode = dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback

-- adding schedule(s)
exec @ReturnCode = dbo.sp_add_jobschedule @job_id=@jobId, @name=N'S1', 
	@enabled=1, 
	@freq_type=4, 
	@freq_interval=1, 
	@freq_subday_type=1, 
	@freq_subday_interval=6, 
	@freq_relative_interval=0, 
	@freq_recurrence_factor=0, 
	@active_start_date=20000101, 
	@active_end_date=99991231, 
	@active_start_time=111111
if (@@error <> 0 or @ReturnCode <> 0) goto QuitWithRollback

commit transaction
goto EndSave
QuitWithRollback:
	if (@@trancount > 0) rollback transaction
EndSave:
go
