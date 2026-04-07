USE [BlogDB]
GO

IF EXISTS (
    SELECT 1
    FROM [dbo].[ApplicationUser]
    WHERE [Username] = 'adminlab'
)
BEGIN
    UPDATE [dbo].[ApplicationUser]
    SET
        [NormalizedUsername] = 'ADMINLAB',
        [Email] = 'admin@bloglab.local',
        [NormalizedEmail] = 'ADMIN@BLOGLAB.LOCAL',
        [Fullname] = 'BlogLab Admin',
        [PasswordHash] = 'AQAAAAIAAYagAAAAECTZEpjVwQVR6BWLs7YCIqwkJ3iLUn8Sbb1c9R5XQ1qQIUwHL+EuCRcHNrSoAdQk7g==',
        [IsAdmin] = CONVERT([bit], (1))
    WHERE [Username] = 'adminlab';
END
ELSE
BEGIN
    INSERT INTO [dbo].[ApplicationUser]
        ([Username], [NormalizedUsername], [Email], [NormalizedEmail], [Fullname], [PasswordHash], [IsAdmin])
    VALUES
        ('adminlab', 'ADMINLAB', 'admin@bloglab.local', 'ADMIN@BLOGLAB.LOCAL', 'BlogLab Admin', 'AQAAAAIAAYagAAAAECTZEpjVwQVR6BWLs7YCIqwkJ3iLUn8Sbb1c9R5XQ1qQIUwHL+EuCRcHNrSoAdQk7g==', CONVERT([bit], (1)));
END
GO