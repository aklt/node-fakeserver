# Fake Server

Write a text describing how a TCP server should respond to requests.  Useful
for testing.

Usage in a console:

```sh
$ fakeserver myscript
```

or from a script:

```coffee
f1 = new FakeServer {
    script: "#{__dirname}/myscript"
    port: 1020
}
f1.listen()
...
```
## Scripts

Scripts consist of a title and a number of lines specifying the communication:

**<** specifies input interpreted as a regex

**>** specifies output 
    
* Can contain references to input using $1..$9 
* Binary values can be specified with \\xHH or \\xHHHH

**=**
    Specifies a function to create the output recieving the captures from
    the input regex as arguments.

Have a look at the `examples/` directory.
