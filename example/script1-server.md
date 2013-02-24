--
port: 10000
--
# Send CAPABILITY string

> * OK IMAP4 ready

# IMAP login

< ^(\w+) LOGIN (\S+) (\S+)
> $1 OK

# List mailboxes

< ^(\w+) LIST (\S+)
= (tag, data) ->
    result = []
    i = 0
    loop
      i += 1
      if i > 9
        break
      result.push "* line #{i}"
    return "#{result.join("\r\n")}\r\n#{tag} OK"

# Select mailbox

< ^(\w+) SELECT (\S+)
> * EXISTS 100
  * UIDVALIDITY 123
  * MODSEQ 234
  $1 OK $2 SELECTED

# Logout

< (\S+) LOGOUT
= -> @.end()
