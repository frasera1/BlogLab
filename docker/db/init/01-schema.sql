-- Generated from AFMAIN\AFMAINSQL22 / BlogDB on 2026-03-06T20:54:25
USE [BlogDB]
GO

-- Schemas

/****** Object:  Schema [aggregate]    Script Date: 3/6/2026 8:55:36 PM ******/
CREATE SCHEMA [aggregate]

GO

-- User-defined table types

/****** Object:  UserDefinedTableType [dbo].[AccountType]    Script Date: 3/6/2026 8:55:36 PM ******/
CREATE TYPE [dbo].[AccountType] AS TABLE(
	[Username] [varchar](20) NOT NULL,
	[NormalizedUsername] [varchar](20) NOT NULL,
	[Email] [varchar](30) NOT NULL,
	[NormalizedEmail] [varchar](30) NOT NULL,
	[Fullname] [varchar](30) NULL,
	[PasswordHash] [nvarchar](max) NOT NULL,
	[IsAdmin] [bit] NOT NULL
)

GO

/****** Object:  UserDefinedTableType [dbo].[BlogCommentType]    Script Date: 3/6/2026 8:55:36 PM ******/
CREATE TYPE [dbo].[BlogCommentType] AS TABLE(
	[BlogCommentId] [int] NOT NULL,
	[ParentBlogCommentId] [int] NULL,
	[BlogId] [int] NOT NULL,
	[Content] [varchar](300) NOT NULL
)

GO

/****** Object:  UserDefinedTableType [dbo].[BlogType]    Script Date: 3/6/2026 8:55:36 PM ******/
CREATE TYPE [dbo].[BlogType] AS TABLE(
	[BlogId] [int] NOT NULL,
	[Title] [varchar](50) NOT NULL,
	[Content] [varchar](max) NOT NULL,
	[PhotoId] [int] NULL
)

GO

/****** Object:  UserDefinedTableType [dbo].[PhotoType]    Script Date: 3/6/2026 8:55:36 PM ******/
CREATE TYPE [dbo].[PhotoType] AS TABLE(
	[PublicId] [varchar](50) NOT NULL,
	[ImageUrl] [varchar](250) NOT NULL,
	[Description] [varchar](30) NOT NULL
)

GO

-- Tables

/****** Object:  Table [dbo].[ApplicationUser]    Script Date: 3/6/2026 8:55:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ApplicationUser](
	[ApplicationUserId] [int] IDENTITY(1,1) NOT NULL,
	[Username] [varchar](20) NOT NULL,
	[NormalizedUsername] [varchar](20) NOT NULL,
	[Email] [varchar](30) NOT NULL,
	[NormalizedEmail] [varchar](30) NOT NULL,
	[Fullname] [varchar](30) NULL,
	[PasswordHash] [nvarchar](max) NOT NULL,
	[IsAdmin] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ApplicationUserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

ALTER TABLE [dbo].[ApplicationUser] ADD  DEFAULT (CONVERT([bit],(0))) FOR [IsAdmin]

SET ANSI_PADDING ON

/****** Object:  Index [ix_ApplicationUser_NormalizedEmail]    Script Date: 3/6/2026 8:55:51 PM ******/
CREATE NONCLUSTERED INDEX [ix_ApplicationUser_NormalizedEmail] ON [dbo].[ApplicationUser]
(
	[NormalizedEmail] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

/****** Object:  Index [ix_ApplicationUser_NormalizedUsername]    Script Date: 3/6/2026 8:55:51 PM ******/
CREATE NONCLUSTERED INDEX [ix_ApplicationUser_NormalizedUsername] ON [dbo].[ApplicationUser]
(
	[NormalizedUsername] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

GO

/****** Object:  Table [dbo].[Photo]    Script Date: 3/6/2026 8:55:54 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Photo](
	[PhotoId] [int] IDENTITY(1,1) NOT NULL,
	[ApplicationUserId] [int] NOT NULL,
	[PublicId] [varchar](50) NOT NULL,
	[ImageUrl] [varchar](250) NOT NULL,
	[Description] [varchar](30) NOT NULL,
	[PublishDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[PhotoId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[Photo] ADD  DEFAULT (getdate()) FOR [PublishDate]
ALTER TABLE [dbo].[Photo] ADD  DEFAULT (getdate()) FOR [UpdateDate]
ALTER TABLE [dbo].[Photo]  WITH CHECK ADD FOREIGN KEY([ApplicationUserId])
REFERENCES [dbo].[ApplicationUser] ([ApplicationUserId])

GO

/****** Object:  Table [dbo].[Blog]    Script Date: 3/6/2026 8:55:57 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Blog](
	[BlogId] [int] IDENTITY(1,1) NOT NULL,
	[ApplicationUserId] [int] NOT NULL,
	[PhotoId] [int] NULL,
	[Title] [varchar](50) NOT NULL,
	[Content] [varchar](max) NOT NULL,
	[PublishDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NOT NULL,
	[ActiveInd] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[BlogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

ALTER TABLE [dbo].[Blog] ADD  DEFAULT (getdate()) FOR [PublishDate]
ALTER TABLE [dbo].[Blog] ADD  DEFAULT (getdate()) FOR [UpdateDate]
ALTER TABLE [dbo].[Blog] ADD  DEFAULT (CONVERT([bit],(1))) FOR [ActiveInd]
ALTER TABLE [dbo].[Blog]  WITH CHECK ADD FOREIGN KEY([ApplicationUserId])
REFERENCES [dbo].[ApplicationUser] ([ApplicationUserId])
ALTER TABLE [dbo].[Blog]  WITH CHECK ADD FOREIGN KEY([PhotoId])
REFERENCES [dbo].[Photo] ([PhotoId])

GO

/****** Object:  Table [dbo].[BlogComment]    Script Date: 3/6/2026 8:55:59 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BlogComment](
	[BlogCommentId] [int] IDENTITY(1,1) NOT NULL,
	[ParentBlogCommentId] [int] NULL,
	[BlogId] [int] NOT NULL,
	[ApplicationUserId] [int] NOT NULL,
	[Content] [varchar](300) NOT NULL,
	[PublishDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NOT NULL,
	[ActiveInd] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[BlogCommentId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[BlogComment] ADD  DEFAULT (getdate()) FOR [PublishDate]
ALTER TABLE [dbo].[BlogComment] ADD  DEFAULT (getdate()) FOR [UpdateDate]
ALTER TABLE [dbo].[BlogComment] ADD  DEFAULT (CONVERT([bit],(1))) FOR [ActiveInd]
ALTER TABLE [dbo].[BlogComment]  WITH CHECK ADD FOREIGN KEY([ApplicationUserId])
REFERENCES [dbo].[ApplicationUser] ([ApplicationUserId])
ALTER TABLE [dbo].[BlogComment]  WITH CHECK ADD FOREIGN KEY([BlogId])
REFERENCES [dbo].[Blog] ([BlogId])

GO

/****** Object:  Table [dbo].[BlogLike]    Script Date: 3/7/2026 12:00:00 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BlogLike](
	[BlogLikeId] [int] IDENTITY(1,1) NOT NULL,
	[BlogId] [int] NOT NULL,
	[ApplicationUserId] [int] NOT NULL,
	[PublishDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NOT NULL,
	[ActiveInd] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[BlogLikeId] ASC
),
	CONSTRAINT [UQ_BlogLike_BlogId_ApplicationUserId] UNIQUE NONCLUSTERED 
	(
		[BlogId] ASC,
		[ApplicationUserId] ASC
	)
) ON [PRIMARY]

ALTER TABLE [dbo].[BlogLike] ADD  DEFAULT (getdate()) FOR [PublishDate]
ALTER TABLE [dbo].[BlogLike] ADD  DEFAULT (getdate()) FOR [UpdateDate]
ALTER TABLE [dbo].[BlogLike] ADD  DEFAULT (CONVERT([bit],(1))) FOR [ActiveInd]
ALTER TABLE [dbo].[BlogLike]  WITH CHECK ADD FOREIGN KEY([ApplicationUserId])
REFERENCES [dbo].[ApplicationUser] ([ApplicationUserId])
ALTER TABLE [dbo].[BlogLike]  WITH CHECK ADD FOREIGN KEY([BlogId])
REFERENCES [dbo].[Blog] ([BlogId])

GO

-- Views

/****** Object:  View [aggregate].[Blog]    Script Date: 3/6/2026 8:56:00 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [aggregate].[Blog]
AS
	SELECT
		t1.BlogId,
		t1.ApplicationUserId,
		t2.Username,
		t1.Title,
		t1.Content,
		t1.PhotoId,
		t1.PublishDate,
		t1.UpdateDate,
		t1.ActiveInd
	FROM
		dbo.Blog t1
	INNER JOIN
		dbo.ApplicationUser t2 ON t1.ApplicationUserId = t2.ApplicationUserId

GO

/****** Object:  View [aggregate].[BlogComment]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [aggregate].[BlogComment]
AS
	SELECT
		t1.BlogCommentId,
		t1.ParentBlogCommentId,
		t1.BlogId,
		t1.Content,
		t1.ApplicationUserId,
		t2.Username,
		t1.PublishDate,
		t1.UpdateDate,
		t1.ActiveInd
	FROM
		dbo.BlogComment t1
	INNER JOIN
		dbo.ApplicationUser t2 ON t1.ApplicationUserId = t2.ApplicationUserId

GO

-- Stored procedures

/****** Object:  StoredProcedure [dbo].[Account_GetByUsername]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Account_GetByUsername]
	@NormalizedUsername VARCHAR(20)
AS
	SELECT 
		[ApplicationUserId]
		,[Username]
		,[NormalizedUsername]
		,[Email]
		,[NormalizedEmail]
		,[Fullname]
		,[PasswordHash]
		,[IsAdmin]
	FROM 
		[dbo].[ApplicationUser] t1
	WHERE
		t1.[NormalizedUsername] = @NormalizedUsername







GO

/****** Object:  StoredProcedure [dbo].[Account_Insert]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Account_Insert]
	@Account AccountType READONLY
AS
	INSERT INTO
		[dbo].[ApplicationUser]
		([Username]
		,[NormalizedUsername]
		,[Email]
		,[NormalizedEmail]
		,[Fullname]
		,[PasswordHash]
		,[IsAdmin])
		 
	SELECT
		[Username]
		,[NormalizedUsername]
		,[Email]
		,[NormalizedEmail]
		,[Fullname]
		,[PasswordHash]
		,[IsAdmin]
	FROM
		@Account;

	SELECT CAST(SCOPE_IDENTITY() AS INT);

GO

/****** Object:  StoredProcedure [dbo].[Blog_Delete]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Blog_Delete]
	@BlogId INT
AS

	UPDATE [dbo].[BlogLike]
	SET
		[ActiveInd] = CONVERT(BIT, 0),
		[UpdateDate] = GETDATE()
	WHERE
		[BlogId] = @BlogId;

	UPDATE [dbo].[BlogComment]
	SET 
		[ActiveInd] = CONVERT(BIT, 0),
		[UpdateDate] = GETDATE()
	WHERE 
		[BlogId] = @BlogId;

	UPDATE [dbo].[Blog]
	SET
		[PhotoId] = NULL,
		[ActiveInd] = CONVERT(BIT, 0),
		[UpdateDate] = GETDATE()
	WHERE
		[BlogId] = @BlogId


GO

/****** Object:  StoredProcedure [dbo].[Blog_Get]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Blog_Get]
	@BlogId INT,
	@CurrentApplicationUserId INT = NULL
AS
	SELECT 
		t1.[BlogId]
	   ,t1.[ApplicationUserId]
	       ,t1.[Username]
	       ,t1.[Title]
	       ,t1.[Content]
	       ,t1.[PhotoId]
	       ,ISNULL(t2.[LikeCount], 0) [LikeCount]
	       ,CASE WHEN t3.[BlogLikeId] IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END [LikedByCurrentUser]
	       ,t1.[PublishDate]
	       ,t1.[UpdateDate]
	 FROM
		[aggregate].[Blog] t1
	LEFT JOIN
		(
			SELECT
				[BlogId],
				COUNT(*) [LikeCount]
			FROM
				[dbo].[BlogLike]
			WHERE
				[ActiveInd] = CONVERT(BIT, 1)
			GROUP BY
				[BlogId]
		) t2 ON t1.[BlogId] = t2.[BlogId]
	LEFT JOIN
		[dbo].[BlogLike] t3 ON t1.[BlogId] = t3.[BlogId]
			AND t3.[ApplicationUserId] = @CurrentApplicationUserId
			AND t3.[ActiveInd] = CONVERT(BIT, 1)
	 WHERE
		t1.[BlogId] = @BlogId AND
		t1.ActiveInd = CONVERT(BIT, 1)


GO

/****** Object:  StoredProcedure [dbo].[Blog_GetAll]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Blog_GetAll]
	@Offset INT,
	@PageSize INT,
	@CurrentApplicationUserId INT = NULL
AS
	SELECT 
		t1.[BlogId]
	   ,t1.[ApplicationUserId]
	       ,t1.[Username]
	       ,t1.[Title]
	       ,t1.[Content]
	       ,t1.[PhotoId]
	       ,ISNULL(t2.[LikeCount], 0) [LikeCount]
	       ,CASE WHEN t3.[BlogLikeId] IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END [LikedByCurrentUser]
	       ,t1.[PublishDate]
	       ,t1.[UpdateDate]
	 FROM
		[aggregate].[Blog] t1
	LEFT JOIN
		(
			SELECT
				[BlogId],
				COUNT(*) [LikeCount]
			FROM
				[dbo].[BlogLike]
			WHERE
				[ActiveInd] = CONVERT(BIT, 1)
			GROUP BY
				[BlogId]
		) t2 ON t1.[BlogId] = t2.[BlogId]
	LEFT JOIN
		[dbo].[BlogLike] t3 ON t1.[BlogId] = t3.[BlogId]
			AND t3.[ApplicationUserId] = @CurrentApplicationUserId
			AND t3.[ActiveInd] = CONVERT(BIT, 1)
	 WHERE
		t1.[ActiveInd] = CONVERT(BIT, 1)
	 ORDER BY
		t1.[BlogId]
	 OFFSET @Offset ROWS
	 FETCH NEXT @PageSize ROWS ONLY;

	 SELECT COUNT(*) FROM [aggregate].[Blog] t1 WHERE t1.[ActiveInd] = CONVERT(BIT, 1);


GO

/****** Object:  StoredProcedure [dbo].[Blog_GetAllFamous]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Blog_GetAllFamous]
	@CurrentApplicationUserId INT = NULL
AS

	SELECT 
	TOP 6
		 t1.[BlogId]
		,t1.[ApplicationUserId]
		,t1.[Username]
		,t1.[PhotoId]
		,t1.[Title]
		,t1.[Content]
			,ISNULL(t3.[LikeCount], 0) [LikeCount]
			,CONVERT(BIT, MAX(CASE WHEN t4.[BlogLikeId] IS NULL THEN 0 ELSE 1 END)) [LikedByCurrentUser]
		,t1.[PublishDate]
		,t1.[UpdateDate]
	FROM 
		[aggregate].[Blog] t1
	INNER JOIN
		[dbo].[BlogComment] t2 ON t1.BlogId = t2.BlogId
		LEFT JOIN
			(
				SELECT
					[BlogId],
					COUNT(*) [LikeCount]
				FROM
					[dbo].[BlogLike]
				WHERE
					[ActiveInd] = CONVERT(BIT, 1)
				GROUP BY
					[BlogId]
			) t3 ON t1.[BlogId] = t3.[BlogId]
		LEFT JOIN
			[dbo].[BlogLike] t4 ON t1.[BlogId] = t4.[BlogId]
				AND t4.[ApplicationUserId] = @CurrentApplicationUserId
				AND t4.[ActiveInd] = CONVERT(BIT, 1)
	WHERE
		t1.[ActiveInd] = CONVERT(BIT, 1) AND
		t2.[ActiveInd] = CONVERT(BIT, 1)
	GROUP BY
		t1.[BlogId]
	   ,t1.[ApplicationUserId]
	   ,t1.[Username]
	   ,t1.[PhotoId]
	   ,t1.[Title]
	   ,t1.[Content]
		   ,ISNULL(t3.[LikeCount], 0)
	   ,t1.[PublishDate]
	   ,t1.[UpdateDate]
	ORDER BY
		COUNT(t2.BlogCommentId)
	DESC


GO

/****** Object:  StoredProcedure [dbo].[Blog_GetByUserId]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Blog_GetByUserId]
	@ApplicationUserId INT,
	@CurrentApplicationUserId INT = NULL
AS
	SELECT 
		t1.[BlogId]
	   ,t1.[ApplicationUserId]
	       ,t1.[Username]
	       ,t1.[Title]
	       ,t1.[Content]
	       ,t1.[PhotoId]
	       ,ISNULL(t2.[LikeCount], 0) [LikeCount]
	       ,CASE WHEN t3.[BlogLikeId] IS NULL THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END [LikedByCurrentUser]
	       ,t1.[PublishDate]
	       ,t1.[UpdateDate]
	 FROM
		[aggregate].[Blog] t1
	LEFT JOIN
		(
			SELECT
				[BlogId],
				COUNT(*) [LikeCount]
			FROM
				[dbo].[BlogLike]
			WHERE
				[ActiveInd] = CONVERT(BIT, 1)
			GROUP BY
				[BlogId]
		) t2 ON t1.[BlogId] = t2.[BlogId]
	LEFT JOIN
		[dbo].[BlogLike] t3 ON t1.[BlogId] = t3.[BlogId]
			AND t3.[ApplicationUserId] = @CurrentApplicationUserId
			AND t3.[ActiveInd] = CONVERT(BIT, 1)
	 WHERE
		t1.[ApplicationUserId] = @ApplicationUserId AND
		t1.[ActiveInd] = CONVERT(BIT, 1)


GO

/****** Object:  StoredProcedure [dbo].[BlogLike_Toggle]    Script Date: 3/7/2026 12:00:00 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[BlogLike_Toggle]
	@BlogId INT,
	@ApplicationUserId INT
AS

	MERGE INTO [dbo].[BlogLike] TARGET
	USING (
		SELECT
			@BlogId [BlogId],
			@ApplicationUserId [ApplicationUserId]
	) AS SOURCE
	ON
	(
		TARGET.[BlogId] = SOURCE.[BlogId] AND TARGET.[ApplicationUserId] = SOURCE.[ApplicationUserId]
	)
	WHEN MATCHED THEN
		UPDATE SET
			TARGET.[ActiveInd] = CASE WHEN TARGET.[ActiveInd] = CONVERT(BIT, 1) THEN CONVERT(BIT, 0) ELSE CONVERT(BIT, 1) END,
			TARGET.[UpdateDate] = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			[BlogId],
			[ApplicationUserId]
		)
		VALUES (
			SOURCE.[BlogId],
			SOURCE.[ApplicationUserId]
		);

	SELECT
		@BlogId [BlogId],
		COUNT(*) [LikeCount],
		CONVERT(BIT, ISNULL(MAX(CASE WHEN [ApplicationUserId] = @ApplicationUserId THEN 1 ELSE 0 END), 0)) [LikedByCurrentUser]
	FROM
		[dbo].[BlogLike]
	WHERE
		[BlogId] = @BlogId AND
		[ActiveInd] = CONVERT(BIT, 1);


GO

/****** Object:  StoredProcedure [dbo].[Blog_Upsert]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Blog_Upsert]
	@Blog BlogType READONLY,
	@ApplicationUserId INT
AS

	MERGE INTO [dbo].[Blog] TARGET
	USING (
		SELECT
			[BlogId],
			@ApplicationUserId [ApplicationUserId],
			[Title],
			[Content],
			[PhotoId]
		FROM
			@Blog
	) AS SOURCE
	ON 
	(
		TARGET.[BlogId] = SOURCE.[BlogId] AND TARGET.[ApplicationUserId] = SOURCE.[ApplicationUserId]
	)
	WHEN MATCHED THEN
		UPDATE SET
			TARGET.[Title] = SOURCE.[Title],
			TARGET.[Content] = SOURCE.[Content],
			TARGET.[PhotoId] = SOURCE.[PhotoId],
			TARGET.[UpdateDate] = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			[ApplicationUserId],
			[Title],
			[Content],
			[PhotoId]
		)
		VALUES (
			SOURCE.[ApplicationUserId],
			SOURCE.[Title],
			SOURCE.[Content],
			SOURCE.[PhotoId]
		);

	SELECT CAST(SCOPE_IDENTITY() AS INT);


GO

/****** Object:  StoredProcedure [dbo].[BlogComment_Delete]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[BlogComment_Delete]
	@BlogCommentId INT
AS

	DROP TABLE IF EXISTS #BlogCommentsToBeDeleted;

	WITH cte_blogComments AS (
		SELECT
			t1.[BlogCommentId],
			t1.[ParentBlogCommentId]
		FROM
			[dbo].[BlogComment] t1
		WHERE
			t1.[BlogCommentId] = @BlogCommentId
		UNION ALL
		SELECT
			t2.[BlogCommentId],
			t2.[ParentBlogCommentId]
		FROM
			[dbo].[BlogComment] t2
			INNER JOIN cte_blogComments t3
				ON t3.[BlogCommentId] = t2.[ParentBlogCommentId]
	)
	SELECT
		[BlogCommentId],
		[ParentBlogCommentId]
	INTO
		#BlogCommentsToBeDeleted
	FROM
		cte_blogComments;

	UPDATE t1
	SET
		t1.[ActiveInd] = CONVERT(BIT, 0),
		t1.[UpdateDate] = GETDATE()
	FROM
		[dbo].[BlogComment] t1
		INNER JOIN #BlogCommentsToBeDeleted t2
			ON t1.[BlogCommentId]= t2.[BlogCommentId];


GO

/****** Object:  StoredProcedure [dbo].[BlogComment_Get]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[BlogComment_Get]
	@BlogCommentId INT
AS

	SELECT 
		 t1.[BlogCommentId]
		,t1.[ParentBlogCommentId]
		,t1.[BlogId]
		,t1.[ApplicationUserId]
		,t1.[Username]
		,t1.[Content]
		,t1.[PublishDate]
		,t1.[UpdateDate]
	FROM 
		[aggregate].[BlogComment] t1
	WHERE
		t1.[BlogCommentId] = @BlogCommentId AND
		t1.[ActiveInd] = CONVERT(BIT, 1)


GO

/****** Object:  StoredProcedure [dbo].[BlogComment_GetAll]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[BlogComment_GetAll]
	@BlogId INT
AS
	
	SELECT 
		 t1.[BlogCommentId]
		,t1.[ParentBlogCommentId]
		,t1.[BlogId]
		,t1.[ApplicationUserId]
		,t1.[Username]
		,t1.[Content]
		,t1.[PublishDate]
		,t1.[UpdateDate]
	FROM 
		[aggregate].[BlogComment] t1
	WHERE
		t1.[BlogId] = @BlogId AND
		t1.[ActiveInd] = CONVERT(BIT, 1)
	ORDER BY
		t1.[UpdateDate]
	DESC




GO

/****** Object:  StoredProcedure [dbo].[BlogComment_Upsert]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[BlogComment_Upsert]
	@BlogComment BlogCommentType READONLY,
	@ApplicationUserId INT
AS

	MERGE INTO [dbo].[BlogComment] TARGET
	USING (
		SELECT 
			[BlogCommentId],
			[ParentBlogCommentId],
			[BlogId],
			[Content],
			@ApplicationUserId [ApplicationUserId]
		FROM
		@BlogComment
	) AS SOURCE
	ON
	(
		TARGET.[BlogCommentId] = SOURCE.[BlogCommentId] AND TARGET.[ApplicationUserId] = SOURCE.[ApplicationUserId]
	)
	WHEN MATCHED THEN
		UPDATE SET
			TARGET.[Content] = SOURCE.[Content],
			TARGET.[UpdateDate] = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			[ParentBlogCommentId],
			[BlogId],
			[ApplicationUserId],
			[Content]
		)
		VALUES
		(	
			SOURCE.[ParentBlogCommentId],
			SOURCE.[BlogId],
			SOURCE.[ApplicationUserId],
			SOURCE.[Content]
		);

	SELECT CAST(SCOPE_IDENTITY() AS INT);


GO

/****** Object:  StoredProcedure [dbo].[Photo_Delete]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Photo_Delete]
	@PhotoId INT
AS

	DELETE FROM [dbo].[Photo] WHERE [PhotoId] = @PhotoId


GO

/****** Object:  StoredProcedure [dbo].[Photo_Get]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Photo_Get]
	@PhotoId INT
AS

	SELECT
		 t1.[PhotoId]
		,t1.[ApplicationUserId]
		,t1.[PublicId]
		,t1.[ImageUrl]
		,t1.[Description]
		,t1.[PublishDate]
		,t1.[UpdateDate]
	FROM 
		[dbo].[Photo] t1
	WHERE
		t1.[PhotoId] = @PhotoId



GO

/****** Object:  StoredProcedure [dbo].[Photo_GetByUserId]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Photo_GetByUserId]
	@ApplicationUserId INT
AS

	SELECT
		 t1.[PhotoId]
		,t1.[ApplicationUserId]
		,t1.[PublicId]
		,t1.[ImageUrl]
		,t1.[Description]
		,t1.[PublishDate]
		,t1.[UpdateDate]
	FROM 
		[dbo].[Photo] t1
	WHERE
		t1.[ApplicationUserId] = @ApplicationUserId


GO

/****** Object:  StoredProcedure [dbo].[Photo_Insert]    Script Date: 3/6/2026 8:56:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Photo_Insert]
	@Photo PhotoType READONLY,
	@ApplicationUserId INT
AS

	INSERT INTO [dbo].[Photo]
           ([ApplicationUserId]
           ,[PublicId]
           ,[ImageUrl]
           ,[Description])
	SELECT 
		@ApplicationUserId,
		[PublicId],
		[ImageUrl],
		[Description]
	FROM
		@Photo;

	SELECT CAST(SCOPE_IDENTITY() AS INT);


GO

