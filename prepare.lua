local t = ...

local pl = require'pl.import_into'()
print(pl.path.currentdir())

-- Filter the jonchki XML with the VCS ID.
t:filterVcsId('../..', '../../jonchki.xml', 'jonchki.xml')

return true
