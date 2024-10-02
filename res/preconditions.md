# List main preconditions
- Check free space on disk.
- Checking for previously deployed DC.
-  

# List my changes in script
- Add the ability to enter arguments when running the script (--help ; -v ; ).
- The rollback function (tmp catalog).
- Checking for the correct domain name (example: dc.domain.alt).
    - There are no special (hard, cyrillic, asian) characters, except dash (-) and numbers.
    - Start and end symbol not a number, dash and any other symbol.
    - The domain name contains three words and 2 dots in domain name.
    - Lenght TLD at least 2 characters and no more 3.
    - Lenght subdomain at least 1 character and no more 25.
    - Lenght domain at least 5 characters and no more 25.
    - There is no repetition of a domain with a subdomain.
- Add more cycles for reading expressions
- Checking for the correct admin password
