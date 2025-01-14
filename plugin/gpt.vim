command -nargs=* -range Gpt call gpt#send(<q-args>, "smart")
command -nargs=* -range GptDepeSeek call gpt#send(<q-args>, "deepseek-coder-v2:16b")
command -nargs=* -range GptSmart call gpt#send(<q-args>, "smart")
command -nargs=* -range GptComplete call gpt#complete(<q-args>, "smart")
command -nargs=* -range Gptfast call gpt#send(<q-args>, "qwen2.5-coder:3b")
command -nargs=* -range Gptslow call gpt#send(<q-args>, "qwen2.5-coder:14b")
command -nargs=* -range Gptsuperslow call gpt#send(<q-args>, "qwen2.5-coder:32b")
" you can define custom model here... model handling should get some
" improvements at some point.
"command -nargs=* -range Chatgpt4 call gpt#send(<q-args>, "")
command -nargs=* ChatgptSetRole call gpt#set_role(<q-args>)
