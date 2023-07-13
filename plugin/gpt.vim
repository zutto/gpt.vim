command -nargs=* -range Chatgpt call gpt#send(<q-args>, "")
command -nargs=* -range Gpt call gpt#complete(<q-args>, "")
" you can define custom model here... model handling should get some
" improvements at some point.
"command -nargs=* -range Chatgpt4 call gpt#send(<q-args>, "gpt-4")
command -nargs=* ChatgptSetRole call gpt#set_role(<q-args>)
