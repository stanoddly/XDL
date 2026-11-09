# Skip empty items in a preferred locale list

Stock `SDL_GetPreferredLocales` counts commas instead of the locales it parses. An empty item in the list gives a wrong count and wrong entries:

| List | Stock SDL | With this patch |
| --- | --- | --- |
| `en,` | 2 entries: `en`, then one whose language is NULL | 1 entry: `en` |
| `,en` | 2 entries: `,en`, then NULL | 1 entry: `en` |
| `en,,fr` | 3 entries: `en`, `,fr`, then NULL | 2 entries: `en`, `fr` |
| ` , ` | 2 entries: `,`, then NULL | NULL, count 0 |

An app that trusts the count reads a NULL entry or a NULL language. The list comes from the platform or from `SDL_HINT_PREFERRED_LOCALES`.

This patch skips empty items and returns the number of entries it filled in. When no entry is left, it returns NULL with a count of 0, as it does for an empty list.

## Testing

`testautomation --filter Locale` sets `SDL_HINT_PREFERRED_LOCALES` to each list above and checks the count and every entry. Stock SDL fails five checks.
