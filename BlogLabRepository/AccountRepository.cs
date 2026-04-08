using BlogLab.Models.Account;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace BlogLab.Repository
{
    public class AccountRepository : IAccountRepository
    {
        private readonly IConfiguration _config;
        private static readonly IdentityError UserNotFoundError = new IdentityError
        {
            Code = nameof(UserNotFoundError),
            Description = "The account could not be found."
        };

        public AccountRepository(IConfiguration config)
        {
            _config = config;
        }

        public async Task<IdentityResult> CreateAsync(ApplicationUserIdentity user, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var dataTable = new DataTable();
            dataTable.Columns.Add("Username", typeof(string));
            dataTable.Columns.Add("NormalizedUsername", typeof(string));
            dataTable.Columns.Add("Email", typeof(string));
            dataTable.Columns.Add("NormalizedEmail", typeof(string));
            dataTable.Columns.Add("Fullname", typeof(string));
            dataTable.Columns.Add("PasswordHash", typeof(string));
            dataTable.Columns.Add("IsAdmin", typeof(bool));

            dataTable.Rows.Add(
                user.Username,
                user.NormalizedUsername,
                user.Email,
                user.NormalizedEmail,
                user.Fullname,
                user.PasswordHash,
                user.IsAdmin
                );
            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync(cancellationToken);

                await connection.ExecuteAsync(new CommandDefinition(
                    "Account_Insert",
                    new { Account = dataTable.AsTableValuedParameter("dbo.AccountType") },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));
            }

            return IdentityResult.Success;
        }

        public async Task<ApplicationUserIdentity> GetByIdAsync(int applicationUserId, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync(cancellationToken);

                return await connection.QuerySingleOrDefaultAsync<ApplicationUserIdentity>(new CommandDefinition(
                    "Account_GetById",
                    new { ApplicationUserId = applicationUserId },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));
            }
        }

        public async Task<ApplicationUserIdentity> GetByUsernameAsync(string normalizedUsername, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync(cancellationToken);

                return await connection.QuerySingleOrDefaultAsync<ApplicationUserIdentity>(new CommandDefinition(
                    "Account_GetByUsername",
                    new { NormalizedUsername = normalizedUsername },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));
            }
        }

        public async Task<IdentityResult> UpdateAsync(ApplicationUserIdentity user, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync(cancellationToken);

                var affectedRows = await connection.ExecuteAsync(new CommandDefinition(
                    "Account_Update",
                    new
                    {
                        user.ApplicationUserId,
                        user.Username,
                        user.NormalizedUsername,
                        user.Email,
                        user.NormalizedEmail,
                        user.Fullname,
                        user.PasswordHash,
                        user.IsAdmin
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

                return affectedRows > 0
                    ? IdentityResult.Success
                    : IdentityResult.Failed(UserNotFoundError);
            }
        }

        public async Task<IdentityResult> DeleteAsync(int applicationUserId, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync(cancellationToken);

                var affectedRows = await connection.ExecuteAsync(new CommandDefinition(
                    "Account_Delete",
                    new { ApplicationUserId = applicationUserId },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

                return affectedRows > 0
                    ? IdentityResult.Success
                    : IdentityResult.Failed(UserNotFoundError);
            }
        }
    }
}
