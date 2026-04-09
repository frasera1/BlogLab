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

CREATE OR ALTER PROCEDURE [dbo].[Account_DeleteWithDependencies]
    @ApplicationUserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DeletedLikeCount INT = 0;
    DECLARE @DeletedCommentCount INT = 0;
    DECLARE @DeletedBlogCount INT = 0;
    DECLARE @DeletedPhotoCount INT = 0;
    DECLARE @DeletedUserCount INT = 0;
    DECLARE @Username VARCHAR(20);

    SELECT @Username = [Username]
    FROM [dbo].[ApplicationUser]
    WHERE [ApplicationUserId] = @ApplicationUserId;

    IF @Username IS NULL
    BEGIN
        RAISERROR('User does not exist.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DROP TABLE IF EXISTS #BlogsToBeDeleted;
        SELECT
            [BlogId]
        INTO
            #BlogsToBeDeleted
        FROM
            [dbo].[Blog]
        WHERE
            [ApplicationUserId] = @ApplicationUserId;

        DROP TABLE IF EXISTS #CommentSeeds;
        SELECT DISTINCT
            [BlogCommentId]
        INTO
            #CommentSeeds
        FROM
        (
            SELECT
                [BlogCommentId]
            FROM
                [dbo].[BlogComment]
            WHERE
                [ApplicationUserId] = @ApplicationUserId

            UNION

            SELECT
                [BlogCommentId]
            FROM
                [dbo].[BlogComment]
            WHERE
                [BlogId] IN (SELECT [BlogId] FROM #BlogsToBeDeleted)
        ) commentSeeds;

        DROP TABLE IF EXISTS #BlogCommentsToBeDeleted;

        ;WITH cte_blogComments AS (
            SELECT
                [BlogCommentId]
            FROM
                #CommentSeeds
            UNION ALL
            SELECT
                t1.[BlogCommentId]
            FROM
                [dbo].[BlogComment] t1
                INNER JOIN cte_blogComments t2
                    ON t2.[BlogCommentId] = t1.[ParentBlogCommentId]
        )
        SELECT DISTINCT
            [BlogCommentId]
        INTO
            #BlogCommentsToBeDeleted
        FROM
            cte_blogComments;

        DROP TABLE IF EXISTS #BlogLikesToBeDeleted;
        SELECT DISTINCT
            [BlogLikeId]
        INTO
            #BlogLikesToBeDeleted
        FROM
            [dbo].[BlogLike]
        WHERE
            [ApplicationUserId] = @ApplicationUserId OR
            [BlogId] IN (SELECT [BlogId] FROM #BlogsToBeDeleted);

        DELETE t1
        FROM
            [dbo].[BlogLike] t1
            INNER JOIN #BlogLikesToBeDeleted t2
                ON t2.[BlogLikeId] = t1.[BlogLikeId];

        SET @DeletedLikeCount = @@ROWCOUNT;

        DELETE t1
        FROM
            [dbo].[BlogComment] t1
            INNER JOIN #BlogCommentsToBeDeleted t2
                ON t2.[BlogCommentId] = t1.[BlogCommentId];

        SET @DeletedCommentCount = @@ROWCOUNT;

        DELETE t1
        FROM
            [dbo].[Blog] t1
            INNER JOIN #BlogsToBeDeleted t2
                ON t2.[BlogId] = t1.[BlogId];

        SET @DeletedBlogCount = @@ROWCOUNT;

        DELETE FROM [dbo].[Photo]
        WHERE [ApplicationUserId] = @ApplicationUserId;

        SET @DeletedPhotoCount = @@ROWCOUNT;

        DELETE FROM [dbo].[ApplicationUser]
        WHERE [ApplicationUserId] = @ApplicationUserId;

        SET @DeletedUserCount = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH

    SELECT
        @ApplicationUserId [ApplicationUserId],
        @Username [Username],
        @DeletedBlogCount [DeletedBlogCount],
        @DeletedCommentCount [DeletedCommentCount],
        @DeletedLikeCount [DeletedLikeCount],
        @DeletedPhotoCount [DeletedPhotoCount],
        @DeletedUserCount [DeletedUserCount];
END
GO

CREATE OR ALTER PROCEDURE [dbo].[Account_CountAdmins]
AS
    SELECT COUNT(1)
    FROM [dbo].[ApplicationUser]
    WHERE [IsAdmin] = CONVERT([bit], 1);
GO

CREATE OR ALTER PROCEDURE [dbo].[Account_GetAllPaged]
    @Page INT = 1,
    @PageSize INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF (@Page < 1)
    BEGIN
        SET @Page = 1;
    END

    IF (@PageSize < 1)
    BEGIN
        SET @PageSize = 10;
    END

    DECLARE @Offset INT = (@Page - 1) * @PageSize;

    SELECT
        [ApplicationUserId],
        [Username],
        [Fullname],
        [Email],
        [IsAdmin]
    FROM [dbo].[ApplicationUser]
    ORDER BY [ApplicationUserId] DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT COUNT(1)
    FROM [dbo].[ApplicationUser];
END
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