# MCP Integration

Codex SEO can use MCP-backed providers when they are configured in Codex. Missing MCP servers are reported as `setup_required`; workflows should not invent live SERP, map, crawl, or image-generation data.

## Supported Optional Providers

- **DataForSEO**: live SERP, keyword, backlinks, maps, AI visibility, merchant data
- **Firecrawl**: JS-rendered scraping, site maps, full-site crawling
- **Image generation**: SEO images and asset variants through the bundled image-gen workflow
- **Ahrefs**: backlink and organic competitor data
- **Bing Webmaster / IndexNow**: Bing diagnostics and non-Google submission
- **SE Ranking / Profound**: AI share-of-voice and citation tracking
- **Unlighthouse**: local multi-page Lighthouse crawling

## Google API Key Safety

Bundled Google REST clients send API keys in the `X-Goog-Api-Key` header. Do
not place a Google key in a URL query string, log a raw request header, or copy
credential-bearing error output into reports. OAuth and service-account tokens
remain in `~/.config/codex-seo/` with restrictive file permissions.

## Config Location

Prefer Codex config paths:

- Project-local: `.codex/config.toml`
- User-wide: `~/.codex/config.toml`

Keep credentials out of version control. Provider-specific scripts use `~/.config/codex-seo/` for local credentials and read old `~/.config/claude-seo/` files only as migration fallback.

## Extension Helpers

```bash
./extensions/dataforseo/install.sh
./extensions/firecrawl/install.sh
./extensions/banana/install.sh
```

After installation, restart Codex so MCP server definitions are reloaded.
