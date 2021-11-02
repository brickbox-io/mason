# Mason - brickbox.io

Use the mason.py script to connect a new host to the brickbox.io ecosystem.

## Installation

You will need to have an API key before proceeding.

The following command will download the mason.py file.

```bash
sudo wget -qO - mason.brickbox.io | bash -s [API Key]
```

-q
--quiet
    Turn of Wget's output.

-O file
--output-document=file
    The documents will not be written to the appropriate files, but all will be concatenated together and written to file.
    If ‘-’ is used as file, documents will be printed to standard output, disabling link conversion.
