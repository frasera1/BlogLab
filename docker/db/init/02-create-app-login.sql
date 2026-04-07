DECLARE @appUser sysname = N'$(APP_USER)';
DECLARE @appPassword nvarchar(256) = REPLACE(N'$(APP_PASSWORD)', N'''', N'''''');
DECLARE @loginSql nvarchar(max);

IF SUSER_ID(@appUser) IS NULL
BEGIN
    SET @loginSql =
        N'CREATE LOGIN ' + QUOTENAME(@appUser) +
        N' WITH PASSWORD = N''' + @appPassword + N''', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
END
ELSE
BEGIN
    SET @loginSql =
        N'ALTER LOGIN ' + QUOTENAME(@appUser) +
        N' WITH PASSWORD = N''' + @appPassword + N''', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
END

EXEC(@loginSql);
GO

USE [BlogDB];
GO

DECLARE @appUser sysname = N'$(APP_USER)';

IF USER_ID(N'$(APP_USER)') IS NULL
BEGIN
    DECLARE @userSql nvarchar(max) =
        N'CREATE USER ' + QUOTENAME(@appUser) + N' FOR LOGIN ' + QUOTENAME(@appUser) + N';';

    EXEC(@userSql);
END
ELSE
BEGIN
    DECLARE @remapUserSql nvarchar(max) =
        N'ALTER USER ' + QUOTENAME(@appUser) + N' WITH LOGIN = ' + QUOTENAME(@appUser) + N';';

    EXEC(@remapUserSql);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals role_principal ON drm.role_principal_id = role_principal.principal_id
    JOIN sys.database_principals member_principal ON drm.member_principal_id = member_principal.principal_id
    WHERE role_principal.name = N'db_owner'
      AND member_principal.name = N'$(APP_USER)'
)
BEGIN
    DECLARE @roleSql nvarchar(max) =
        N'ALTER ROLE [db_owner] ADD MEMBER ' + QUOTENAME(N'$(APP_USER)') + N';';

    EXEC(@roleSql);
END
GO