#This is a sample backend, that just uses curl & ollama (in my case, open_webui proxying to multiple ollama instances).

When model is "smart" - this backend tries to be smart and decide which model to use:
- fast conversational   (small model) 
- slow conversational   (big model) 
- fast coding           (small coding model)
- slow coding           (big coding model)


#Installation:

1. Edit the top of the ollama_curl file with your own ollama api/models

2. add backend to .vimrc
```
let g:model = "smart"
let g:chatgpt_bin = ["bash", '/usr/local/bin/ollama_curl']
```


3. install the binary:
```
sudo make install
```
(or manually copy to /usr/local/bin/)

