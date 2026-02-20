using Microsoft.Playwright;
using System.Text.Json;

/// <summary>
/// Launches Chrome via Playwright, navigates to recorder.google.com,
/// waits for the user to log in, captures cookies and clientconfig,
/// and outputs JSON on stdout.
///
/// Usage:
///   PlaywrightAuth                      # normal login
///   PlaywrightAuth --force              # clear saved state first
///   PlaywrightAuth --user-data-dir DIR  # custom persistent profile path
///
/// Output (stdout): { "cookieHeader": "...", "apiKey": "...", "email": "...", "baseUrl": "..." }
/// Progress (stderr): status messages for the calling PowerShell process.
/// </summary>
internal class Program
{
    private const string RecorderUrl = "https://recorder.google.com";
    private const string ClientConfigUrl = "https://recorder.google.com/clientconfig";
    private const int LoginTimeoutMs = 15 * 60 * 1000; // 15 minutes

    public static async Task<int> Main(string[] args)
    {
        try
        {
            var force = args.Contains("--force");
            var userDataDir = GetArg(args, "--user-data-dir")
                ?? Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                    ".google-recorder-client", "browser-profile");

            if (force && Directory.Exists(userDataDir))
            {
                Log("--force: deleting saved browser profile...");
                Directory.Delete(userDataDir, recursive: true);
            }

            var isFirstRun = !Directory.Exists(userDataDir);
            Directory.CreateDirectory(userDataDir);

            Log($"Profile: {userDataDir}");
            Log(isFirstRun ? "First run — you will need to log in." : "Reusing saved session...");

            using var playwright = await Playwright.CreateAsync();
            await using var context = await playwright.Chromium.LaunchPersistentContextAsync(
                userDataDir,
                new BrowserTypeLaunchPersistentContextOptions
                {
                    Channel = "chrome",
                    Headless = false,
                    Args = ["--disable-blink-features=AutomationControlled"],
                    ViewportSize = null,
                    IgnoreHTTPSErrors = true,
                });

            var page = context.Pages.Count > 0 ? context.Pages[0] : await context.NewPageAsync();
            await page.GotoAsync(RecorderUrl, new PageGotoOptions
            {
                WaitUntil = WaitUntilState.DOMContentLoaded,
                Timeout = 30_000,
            });

            // Give the page a moment to settle / redirect
            await page.WaitForTimeoutAsync(3000);

            var initialUrl = page.Url;
            var hasAuth = await HasAuthCookies(context);

            if (IsLoggedIn(initialUrl) && hasAuth)
            {
                Log("Existing session is still valid.");
            }
            else
            {
                Log("");
                Log("=== Google Recorder Authentication ===");
                Log("Log into your Google account in the browser window.");
                Log("The script will automatically detect when you are logged in.");
                Log($"Timeout: {LoginTimeoutMs / 60_000} minutes.");
                Log("");

                // Poll until we have BOTH the right URL and auth cookies.
                // The URL alone isn't sufficient — recorder.google.com may load
                // a landing page without redirecting to accounts.google.com.
                var deadline = DateTime.UtcNow.AddMilliseconds(LoginTimeoutMs);
                var loggedIn = false;
                while (DateTime.UtcNow < deadline)
                {
                    if (IsLoggedIn(page.Url) && await HasAuthCookies(context))
                    {
                        loggedIn = true;
                        break;
                    }
                    await page.WaitForTimeoutAsync(2000);
                }

                if (!loggedIn)
                {
                    Log("ERROR: Timed out waiting for login. Please try again.");
                    return 1;
                }

                // Let cookies settle after login
                await page.WaitForTimeoutAsync(2000);
                Log("Login detected!");
            }

            Log("Capturing cookies...");

            // Retrieve cookies — pass no URLs to get ALL cookies from the context
            var allCookies = await context.CookiesAsync();
            var googleCookies = allCookies
                .Where(c => c.Domain.Contains("google.com") || c.Domain.Contains("googleapis.com"))
                .ToList();

            if (googleCookies.Count == 0)
            {
                Log("ERROR: No Google cookies found after login.");
                return 1;
            }

            Log($"Captured {googleCookies.Count} Google cookies.");
            var cookieHeader = string.Join("; ", googleCookies.Select(c => $"{c.Name}={c.Value}"));

            // Fetch clientconfig via JavaScript fetch() to avoid browser treating it as a download
            Log("Fetching API configuration...");
            var configText = await page.EvaluateAsync<string>(@"
                async () => {
                    const r = await fetch('https://recorder.google.com/clientconfig', { credentials: 'include' });
                    return await r.text();
                }
            ");

            // Strip XSSI prefix )]}'\n if present
            if (configText.StartsWith(")]}'"))
            {
                var nlIndex = configText.IndexOf('\n');
                if (nlIndex >= 0) configText = configText[(nlIndex + 1)..];
            }

            using var configDoc = JsonDocument.Parse(configText);
            var root = configDoc.RootElement;

            var result = new
            {
                cookieHeader,
                apiKey = root.GetProperty("apiKey").GetString(),
                email = root.GetProperty("email").GetString(),
                baseUrl = root.GetProperty("firstPartyApiUrl").GetString(),
            };

            // JSON on stdout for the calling PowerShell process
            Console.Write(JsonSerializer.Serialize(result));

            Log("");
            Log("Done. Closing browser.");
            return 0;
        }
        catch (Exception ex)
        {
            Log($"ERROR: {ex.Message}");
            return 1;
        }
    }

    private static bool IsLoggedIn(string url) =>
        url.Contains("recorder.google.com") &&
        !url.Contains("accounts.google.com") &&
        !url.Contains("signin");

    private static async Task<bool> HasAuthCookies(IBrowserContext context)
    {
        var cookies = await context.CookiesAsync();
        string[] authNames = ["SID", "HSID", "SSID", "APISID", "SAPISID"];
        var found = cookies.Count(c => authNames.Contains(c.Name) && c.Domain.Contains("google.com"));
        return found >= 3;
    }

    private static string? GetArg(string[] args, string name)
    {
        var idx = Array.IndexOf(args, name);
        return idx >= 0 && idx + 1 < args.Length ? args[idx + 1] : null;
    }

    private static void Log(string message) => Console.Error.WriteLine(message);
}
