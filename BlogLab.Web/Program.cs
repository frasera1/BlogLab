using BlogLab.Web.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddBlogLabServices(builder.Configuration)
    .AddBlogLabAuthentication(builder.Configuration)
    .AddBlogLabCors()
    .AddBlogLabOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

app.ConfigureExceptionHandler();

app.UseRouting();

app.UseBlogLabCors();
app.UseBlogLabOpenApi();

app.UseAuthentication();
app.UseAuthorization();

app.MapAccountEndpoints();
app.MapBlogEndpoints();
app.MapBlogCommentEndpoints();
app.MapPhotoEndpoints();
app.MapAdminBlogEndpoints();

app.Run();
