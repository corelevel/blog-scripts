use StackOverflow2013
go
set nocount, xact_abort on
set deadlock_priority low

-- It is very important to use an appropriate datatype for primary_key_id matching PK datatype
create table #todo
(
	row_id			int identity(1, 1) not null,
	primary_key_id	int not null
)

create table #state
(
	current_row_id	int not null,
	max_row_id		int not null
)
 
insert	#todo (primary_key_id)
select	Id
from	dbo.Votes
where CreationDate < '2010-01-01'

insert	#state(current_row_id, max_row_id)
values	(1, scope_identity())

create unique clustered index #cix_todo on #todo(row_id) with(data_compression = page)
go

-- Delete cycle. Can be stopped and restarted at any time
-- If the process is stopped, don't forget to roll back the transaction, as it may still be open
declare	@batch_size int = 10000,	-- set the batch size
	@current_row_id int = 1,
	@max_row_id int
 
select	@current_row_id = current_row_id,
		@max_row_id = max_row_id
from	#state

while @current_row_id <= @max_row_id
begin
	begin try
		begin tran
		    -- I typically use a "loop join" because it often delivers the best performance,
		    -- but you should always test other join types or let SQL Server choose the optimal one
			delete  so
			from	#todo t
					inner loop join dbo.Votes so
					on so.Id = t.primary_key_id
			where t.row_id >= @current_row_id and t.row_id < @current_row_id + @batch_size

			update	#state
			set		current_row_id = @current_row_id + @batch_size
		commit tran
	end try
	begin catch
		if @@trancount > 0
		begin
			rollback transaction
		end
		;throw
	end catch

	set @current_row_id = @current_row_id + @batch_size
end