USE [BlogDB]
GO

IF COL_LENGTH('dbo.ApplicationUser', 'IsAdmin') IS NULL
BEGIN
    ALTER TABLE [dbo].[ApplicationUser]
    ADD [IsAdmin] [bit] NOT NULL CONSTRAINT [DF_ApplicationUser_IsAdmin_Reconcile] DEFAULT (CONVERT([bit], (0)));
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.table_types tt
    JOIN sys.columns c ON c.object_id = tt.type_table_object_id
    WHERE tt.schema_id = SCHEMA_ID(N'dbo')
      AND tt.name = N'AccountType'
    GROUP BY tt.name
    HAVING SUM(CASE WHEN c.name = N'IsAdmin' THEN 1 ELSE 0 END) = 0
)
BEGIN
    IF OBJECT_ID(N'dbo.Account_Insert', N'P') IS NOT NULL
    BEGIN
        DROP PROCEDURE [dbo].[Account_Insert];
    END

    DROP TYPE [dbo].[AccountType];
END
GO

IF TYPE_ID(N'dbo.AccountType') IS NULL
BEGIN
    CREATE TYPE [dbo].[AccountType] AS TABLE(
        [Username] [varchar](20) NOT NULL,
        [NormalizedUsername] [varchar](20) NOT NULL,
        [Email] [varchar](30) NOT NULL,
        [NormalizedEmail] [varchar](30) NOT NULL,
        [Fullname] [varchar](30) NULL,
        [PasswordHash] [nvarchar](max) NOT NULL,
        [IsAdmin] [bit] NOT NULL
    );
END
GO

CREATE OR ALTER PROCEDURE [dbo].[Account_GetByUsername]
    @NormalizedUsername VARCHAR(20)
AS
    SELECT
        [ApplicationUserId],
        [Username],
        [NormalizedUsername],
        [Email],
        [NormalizedEmail],
        [Fullname],
        [PasswordHash],
        [IsAdmin]
    FROM
        [dbo].[ApplicationUser] t1
    WHERE
        t1.[NormalizedUsername] = @NormalizedUsername
GO

CREATE OR ALTER PROCEDURE [dbo].[Account_GetById]
    @ApplicationUserId INT
AS
    SELECT
        [ApplicationUserId],
        [Username],
        [NormalizedUsername],
        [Email],
        [NormalizedEmail],
        [Fullname],
        [PasswordHash],
        [IsAdmin]
    FROM
        [dbo].[ApplicationUser] t1
    WHERE
        t1.[ApplicationUserId] = @ApplicationUserId
GO

CREATE OR ALTER PROCEDURE [dbo].[Account_Insert]
    @Account [dbo].[AccountType] READONLY
AS
    INSERT INTO
        [dbo].[ApplicationUser]
        ([Username], [NormalizedUsername], [Email], [NormalizedEmail], [Fullname], [PasswordHash], [IsAdmin])
    SELECT
        [Username], [NormalizedUsername], [Email], [NormalizedEmail], [Fullname], [PasswordHash], [IsAdmin]
    FROM
        @Account;

    SELECT CAST(SCOPE_IDENTITY() AS INT);
GO

CREATE OR ALTER PROCEDURE [dbo].[Account_Update]
    @ApplicationUserId INT,
    @Username VARCHAR(20),
    @NormalizedUsername VARCHAR(20),
    @Email VARCHAR(30),
    @NormalizedEmail VARCHAR(30),
    @Fullname VARCHAR(30) = NULL,
    @PasswordHash NVARCHAR(MAX),
    @IsAdmin BIT
AS
    UPDATE [dbo].[ApplicationUser]
    SET
        [Username] = @Username,
        [NormalizedUsername] = @NormalizedUsername,
        [Email] = @Email,
        [NormalizedEmail] = @NormalizedEmail,
        [Fullname] = @Fullname,
        [PasswordHash] = @PasswordHash,
        [IsAdmin] = @IsAdmin
    WHERE
        [ApplicationUserId] = @ApplicationUserId;

    SELECT @@ROWCOUNT;
GO

CREATE OR ALTER PROCEDURE [dbo].[Account_Delete]
    @ApplicationUserId INT
AS
    DELETE FROM [dbo].[ApplicationUser]
    WHERE [ApplicationUserId] = @ApplicationUserId;

    SELECT @@ROWCOUNT;
GO

IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.BlogComment')
      AND name = N'ParentBlogCommentId'
      AND is_nullable = 0
)
BEGIN
    ALTER TABLE [dbo].[BlogComment]
    ALTER COLUMN [ParentBlogCommentId] [int] NULL;
END
GO