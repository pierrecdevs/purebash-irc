# Purebash IRC

This was inspired by an IRC user named Commander_Keen in the #technicalrenaissance channel on libera.chat irc server.

Big thanks to Dave Eddy (sp?) over on YouTube his tutorials are crazy amazing.

I'm sure this can be improved.

Pull requests welcomed.

## Usage

The `#` needs to be escaped.

More options can be added like debug

It's not a fully featured client it's a proof of concept inspired by Commander_Keen and Dave Eddy

### Options

- `s` - Server to connect to
- `p` - Port to connect to
- `n` - Nickname to use
- `c` - Channel to autojoin
- `v` - Verbose (default: TRUE)

```bash
./irc.sh -s irc.libera.chat -p 6667 -n bash_irc_user -c \#bash-dev
```
