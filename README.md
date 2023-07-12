# gpt.vim

A plugin for interfacing with general purpose text models, such as openai-chatgpt, localai, etc.

## Requirements

An application that accepts a stdin stream of JSON, which is handled. Such an application can be found at [github.com/zutto/python-chatgpt-vimbackend (WIP)](https://github.com/zutto/python-chatgpt-vimbackend) or [github.com/mattn/chatgpt](https://github.com/mattn/chatgpt). You can also build your own simple piped handling.

Example of the JSON stream (all tokens in one chunk. May change in future with longer context support):

```json
{"model": "gpt-4", "text":"Hello world", "systemrole":"custom role"}
```

Example of the expected output stream from the application (streamed per token, or all tokens + EOF):

```json
{"eof": false, "error": "", "text": ""}
{"eof": false, "error": "", "text": "Hello"}
{"eof": false, "error": "", "text": "!"}
{"eof": false, "error": "", "text": " How"}
{"eof": false, "error": "", "text": " can"}
{"eof": false, "error": "", "text": " I"}
{"eof": false, "error": "", "text": " assist"}
{"eof": false, "error": "", "text": " you"}
{"eof": false, "error": "", "text": " today"}
{"eof": false, "error": "", "text": "?"}
{"eof": false, "error": "", "text": ""}
{"eof": false, "error": "", "text": ""}
{"eof": true, "error": "", "text": ""}
```

## Settings

- `g:chatgpt_bin` - Location of the program this plugin interfaces with. Default value: `['python3.11', '/usr/local/bin/chatgpt']`. Example: 
  ```vim
  let g:chatgpt_bin = ['python3.11', '/usr/local/bin/chatgpt']
  ```

- `g:chatgpt_role` - Role to set for the assistant. This is a great place to use augroups to set different roles for different files. The program that interfaces with this plugin should handle updating the role for the assistant as needed. Example:
  ```vim
  let g:chatgpt_role = "You are a helpful commit writer who likes to write easy to understand and compact commit messages."
  ```

## Commands

- `Chatgpt` - Calls the assistant. Note: You highlight contents with visual mode. The highlighted contents will be sent to the assistant along with your request.

- `ChatgptSetRole` - Set a custom role on the fly.

## Credits

mattn's project was an inspiration for this project. This is basically a personal rewrite of the original project: [github.com/mattn/vim-chatgpt](https://github.com/mattn/vim-chatgpt). Give mattn all the love.

## Demo
normal usage
[![asciicast](https://asciinema.org/a/81jVCwHdEmEBSv00Lm71WHazk.svg)](https://asciinema.org/a/81jVCwHdEmEBSv00Lm71WHazk)


Example of using visual mode.
[![asciicast](https://asciinema.org/a/PVKHKSRIYOm7mvohAnCDIuDgB.svg)](https://asciinema.org/a/PVKHKSRIYOm7mvohAnCDIuDgB)

