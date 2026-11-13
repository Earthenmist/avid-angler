-- Avid Angler
-- Spanish (esMX) locale strings.

local _, AvidAngler = ...

if not AvidAngler or not AvidAngler.RegisterLocale then
    return
end

local source = AvidAngler.Locales and AvidAngler.Locales.esES
if source then
    AvidAngler:RegisterLocale("esMX", "Español (AL)", source)
end
