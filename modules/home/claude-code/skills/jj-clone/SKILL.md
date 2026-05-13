---
description: Clone a repository so we can explore it for examination. Use instead of exploring repositories with Fetch or GH cli
---

Our jj config ignores a folder named `.work` by default. 
To examine a repository `$repo`, clone it into the `.work` folder:
```
mkdir -p .work && jj git clone $repo
```


