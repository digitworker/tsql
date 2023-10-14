-- @ID_Record пишется в первой строке т.к. является единственным параметром
create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
-- после as надо указать алиас процедуры
as
set nocount on
begin
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
	declare @ErrorMessage varchar(max)

	-- select и from пишется с отступом tab т.к. находятся в новом блоке if ( )
	-- Комментарий ниже должен учитывать отступ блока, для которого написан
-- Проверка на корректность загрузки
	if not exists (
	select 1
	-- алиас следует назвать ifl
	from syn.ImportFile as f
	where f.ID = @ID_Record
		and f.FlagLoaded = cast(1 as bit)
	)
	-- begin и все вложенные строки нужно ставить на один отступ назад. 
		begin
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'

			raiserror(@ErrorMessage, 3, 1)
			-- Перед return необходимо ставить отступ
			return
		end
	-- Название таблицы не может начинаться на #
	-- Поле ID указывается первым
	CREATE TABLE #ProcessedRows (
		ActionType varchar(255),
		ID int
	)
	
	-- Необходимо поставить пробел между -- и словом в комментарии ниже
	--Чтение из слоя временных данных
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(cs.DateBegin as date) as DateBegin
		,cast(cs.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(cs.FlagActive, 0) as bit) as FlagActive
	-- Название таблицы не может начинаться с #. 
	into #CustomerSeasonal
	-- алиас cs для таблицы необходимо указать после as
	from syn.SA_CustomerSeasonal cs
		join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = cs.Season
		-- Название поля ID_mapping_DataSource должно иметь заглавные буквы каждого слова
		join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		join syn.CustomerSystemType as cst on cs.CustomerSystemType = cst.Name
	where try_cast(cs.DateBegin as date) is not null
		and try_cast(cs.DateEnd as date) is not null
		and try_cast(isnull(cs.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	-- алиас Reason таблицы следует указать с маленькой буквы
	select
		cs.*
		,case
			when cc.ID is null then 'UID клиента отсутствует в справочнике "Клиент"'
			when cd.ID is null then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(cs.DateBegin as date) is null then 'Невозможно определить Дату начала'
			when try_cast(cs.DateEnd as date) is null then 'Невозможно определить Дату начала'
			when try_cast(isnull(cs.FlagActive, 0) as bit) is null then 'Невозможно определить Активность'
		end as Reason
	-- Название таблицы не может начинаться с #. 
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
	-- в поле ID_mapping_DataSource все слова следует делать с заглавных букв
	left join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
		and cc.ID_mapping_DataSource = 1
	-- В left join 'and' ставится на +1 уровень tab от left. Правило: Если есть and , то выравнивать его на 1 табуляцию от join
	-- в поле ID_mapping_DataSource все слова следует делать с заглавных букв
	left join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor and cd.ID_mapping_DataSource = 1
	left join dbo.Season as s on s.Name = cs.Season
	left join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	-- После where необходим переход на следующую строку, т.к. параметр не единственный
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(cs.DateBegin as date) is null
		or try_cast(cs.DateEnd as date) is null
		or try_cast(isnull(cs.FlagActive, 0) as bit) is null
		
end
