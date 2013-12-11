### Binary - To - Text Encoder (64/85 - bit)

Compile with:
```bash
    tasm filter.asm 
    tlink filter
```

Usage:
```bash
   filter.exe [-option] input output

     -h        : Help Screen.
     -e        : Encode to text (Ascii85).
     -d        : Decode from text to binary (Ascii85).
     -E        : Encode to text (Base64).
     -D        : Decode from text to binary (Base64)
     -c        : Make a copy of input to output.
     -v        : Print version information.
```
