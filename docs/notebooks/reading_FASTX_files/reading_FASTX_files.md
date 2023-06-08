# Reading FASTA and FASTQ files
Eric Hunt
2023-06-08

### Package dependencies

``` julia
using FASTX
```

## The problem

*Uhh.. well.. my problem. Someone out there understands all this
perfectly.* 😆

Using the `FASTA`/`FASTQ.Reader` structs from FASTX.jl[^1], which wrap
around an IO, has been confusing me – particularly because the `do`
block syntax makes things less straighforward to immediately understand.

Below is a typical `do` block for using `Base.open` by dispatching the
method:

    open(f::Function, args...; kwargs...)

The docs for this method state:

> Apply the function f to the result of open(args…; kwargs…) and close
> the resulting file descriptor upon completion.

So let’s open an example FASTA file and see what we get:

``` julia
example_file = open("example.fasta", "r") do io
    FASTAReader(io)
end
```

    FASTX.FASTA.Reader{TranscodingStreams.NoopStream{IOStream}}(TranscodingStreams.NoopStream{IOStream}(<mode=idle>), 1, 1, nothing, FASTX.FASTA.Record:
      description: ""
         sequence: "", true)

We get a `FASTX.FASTA.Reader` (`FASTAReader`) with a `NoopStream` IO
stream type. Sweet. I’d love to tell you exactly what this means, but I
don’t really know. I think it means that the IO stream was present, but
the `do` block dispatch of the `Base.open` method shown above closed it
before we really did anything with it, so now we have a placeholder
“no-operation” stream that essentially produces nothing.

Looking into the FASTX.jl docs[^2] they say:

> Readers and writers take control over the underlying IO, and
> manipulating the IO underneath a Reader/Writer, e.g. by flushing or
> closing it, cause them to behave in an undefined manner.
>
> Closing readers/writers closes the underlying IO. Because they carry
> their own buffers, it’s important to remember to close writers in
> particular, else the results may not be fully written to the file.

> Readers are iterables of `Record`.

So can we do something like this..?

``` julia
for record in example_file
    @show record
end
```

..alas, no, because the Reader IO was closed and there aren’t any
records in an no-op stream. 🫥

Somewhat related – and also probably indicative of my technical
understanding or lack thereof – you can’t reopen or initiate the no-op
stream to iterate through records because, perhaps unsurprisingly, there
is no `open` method to dispatch on type
`::FASTX.FASTA.Reader{TranscodingStreams.NoopStream{IOStream}}`.

``` julia
begin
    io = open(example_file)
    for record in io
        @show record
    end
    close(io)
end
```

    LoadError: 
    [2m[31m────────────────────────────────── [22m[1m[31mMethodError[22m[22m[39m[2m[31m [2m[31m─────────────────────────────────[22m[39m[22m[39m[0m[22m[39m
    [2m[38;2;255;138;79m╭──── [22m[1m[38;2;255;138;79mError Stack[22m[22m[39m[2m[38;2;255;138;79m[2m[38;2;255;138;79m ─────────────────────────────────────────────────────────────╮[22m[39m[0m[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m         [0m[38;2;155;179;224m╭───────────────────────────────────────────────────────────╮[39m[0m        [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m         [38;2;155;179;224m│[39m  [38;2;242;215;119mstart_task[39m                                               [38;2;155;179;224m│[39m        [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m         [38;2;155;179;224m│[39m   [22m[1m[2mfrom C[22m[22m[22m                                                  [38;2;155;179;224m│[39m        [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m     [2m(1)[22m [38;2;155;179;224m│[39m  [2m[4m/Users/hunt/.julia/juliaup/julia-1.9.0+0.x64.app[24m[22m         [38;2;155;179;224m│[39m        [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m         [38;2;155;179;224m│[39m  [2m[4mle.darwin14/lib/julia/libjulia-internal.1.9.dyli[24m[22m         [38;2;155;179;224m│[39m        [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m         [38;2;155;179;224m│[39m  [2m[4mb:-1[22m[24m                                                     [38;2;155;179;224m│[39m        [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m         [38;2;155;179;224m╰───────────────────────────────────────────── [37mTOP LEVEL[39m[38;2;155;179;224m[38;2;155;179;224m ───╯[39m[0m[39m[0m        [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m       [38;2;155;179;224m                      Skipped [1m1[22m frame                        [39m          [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;236;64;122m─────────────────────────── [22m[37mIn module [1m[38;2;236;64;122mIJulia[22m[39m[22m[37m[22m[39m[2m[38;2;236;64;122m [2m[38;2;236;64;122m───────────────────────────[22m[39m[22m[39m[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m     [2m(3)[22m    ([38;2;206;147;216m::IJulia.var[39m"#15#18")()                                          [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m             [22m[1m[2mfrom C[22m[22m[22m                                                           [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m     [2m(4)[22m    ([38;2;206;147;216m::IJulia.var[39m"#15#18")()                                          [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m            [2m[4m./task.jl:514[22m[24m                                                     [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m       [38;2;155;179;224m                  Skipped [1m3[22m frames in [38;2;236;64;122mBase[39m                   [39m          [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m            [38;2;242;215;119mexecute_request[39m(socket[38;2;206;147;216m::ZMQ.Socket[39m, msg[38;2;206;147;216m::IJulia.M[39m                 [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m     [2m(8)[22m    [38;2;206;147;216msg[39m)                                                               [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m             [22m[1m[2mfrom C[22m[22m[22m                                                           [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m            [38;2;242;215;119mexecute_request[39m(socket[38;2;206;147;216m::ZMQ.Socket[39m, msg[38;2;206;147;216m::IJulia.M[39m                 [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m            [38;2;206;147;216msg[39m)                                                               [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m            [2m[4m/Users/hunt/.julia/packages/IJulia/Vo51o/src/exe[24m[22m                  [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m     [2m(9)[22m    [2m[4mcute_request.jl:67[22m[24m                                                [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m              [2m│ [22m[0m[2m╭─────────────────────────────────────╮[22m[0m                       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m              [2m╰─[22m[2m│[22m[1m[31m❯[22m[39m [37m67[39m [38;2;232;212;114moccursin[39m[38;2;227;136;100m([39m[38;2;222;222;222mmagics_regex[39m[38;2;227;136;100m,[39m[38;2;222;222;222m [39m[38;2;222;222;222mcode[39m[38;2;227;136;100m)[39m[38;2;222;222;222m[39m... [2m│[22m                       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                [0m[2m╰─────────────────────────────────────╯[22m[0m[0m                       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m       [38;2;155;179;224m                      Skipped [1m1[22m frame                        [39m          [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;236;64;122m─────────────────────── [22m[37mIn module [1m[38;2;236;64;122mSoftGlobalScope[22m[39m[22m[37m[22m[39m[2m[38;2;236;64;122m [2m[38;2;236;64;122m──────────────────────[22m[39m[22m[39m[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m             [38;2;242;215;119msoftscope_include_string[39m(m[38;2;206;147;216m::Module[39m, code[38;2;206;147;216m::String[39m,                [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m              filename[38;2;206;147;216m::String[39m)                                               [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m             [2m[4m/Users/hunt/.julia/packages/SoftGlobalScope/u4Uz[24m[22m                 [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m     [2m(11)[22m    [2m[4mH/src/SoftGlobalScope.jl:65[22m[24m                                      [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m               [2m│ [22m[0m[2m╭──────────────────────────────────────╮[22m[0m                     [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m               [2m╰─[22m[2m│[22m[1m[31m❯[22m[39m [37m65[39m [38;2;232;212;114msoftscope_include_string[39m[38;2;227;136;100m([39m[38;2;222;222;222mm[39m[38;2;222;109;89m::[39m[38;2;222;222;222mM[39m... [2m│[22m                     [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                 [0m[2m╰──────────────────────────────────────╯[22m[0m[0m                     [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m       [38;2;155;179;224m                  Skipped [1m7[22m frames in [38;2;236;64;122mBase[39m                   [39m          [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;155;179;224m────────────────────────────────────────────────────────────────────────[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m  [2m[38;2;236;64;122m──────────────────────────── [22m[37mIn module [1m[38;2;236;64;122mBase[22m[39m[22m[37m[22m[39m[2m[38;2;236;64;122m [2m[38;2;236;64;122m────────────────────────────[22m[39m[22m[39m[0m[22m[39m    [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m          [0m[38;2;155;179;224m╭───────────────────────────────────────────────────────────╮[39m[0m       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m          [38;2;155;179;224m│[39m  [38;2;242;215;119mjl_method_error_bare[39m                                     [38;2;155;179;224m│[39m       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m          [38;2;155;179;224m│[39m   [22m[1m[2mfrom C[22m[22m[22m                                                  [38;2;155;179;224m│[39m       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m     [2m(19)[22m [38;2;155;179;224m│[39m  [2m[4m/Users/hunt/.julia/juliaup/julia-1.9.0+0.x64.app[24m[22m         [38;2;155;179;224m│[39m       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m          [38;2;155;179;224m│[39m  [2m[4mle.darwin14/lib/julia/libjulia-internal.1.9.dyli[24m[22m         [38;2;155;179;224m│[39m       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m          [38;2;155;179;224m│[39m  [2m[4mb:-1[22m[24m                                                     [38;2;155;179;224m│[39m       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m          [38;2;155;179;224m╰──────────────────────────────────────────── [1m[37mERROR LINE[22m[39m[38;2;155;179;224m[38;2;155;179;224m ───╯[39m[0m[39m[0m       [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m│[22m[39m                                                                              [2m[38;2;255;138;79m│[22m[39m
    [2m[38;2;255;138;79m╰──── [22m[1m[38;2;255;138;79mError Stack[22m[22m[39m[2m[38;2;255;138;79m[2m[38;2;255;138;79m ─────────────────────────────────────────────────────────────╯[22m[39m[0m[22m[39m[0m
    [2m[31m╭───────────────────────────────── [0m[22m[1m[4m[31mMethodError[22m[22m[24m[39m[2m[31m ────────────────────────────────╮[22m[39m[0m[22m[39m
    [2m[31m│[22m[39m                                                                              [2m[31m│[22m[39m
    [2m[31m│[22m[39m  MethodError: no method matching open([38;2;206;147;216m::FASTX.FASTA.Reader[39m)                  [2m[31m│[22m[39m
    [2m[31m│[22m[39m                                                                              [2m[31m│[22m[39m
    [2m[31m│[22m[39m  Closest candidates are:                                                     [2m[31m│[22m[39m
    [2m[31m│[22m[39m    open([38;2;239;83;80m![39mMatched[38;2;206;147;216m::Function[39m, [38;2;239;83;80m![39mMatched[38;2;206;147;216m::Base.AbstractCmd[39m, [38;2;239;83;80m![39mMatched[38;2;206;147;216m::Any...[39m;    [2m[31m│[22m[39m
    [2m[31m│[22m[39m   kwargs...)                                                                 [2m[31m│[22m[39m
    [2m[31m│[22m[39m     @ Base process.jl:[38;2;144;202;249m414[39m                                                    [2m[31m│[22m[39m
    [2m[31m│[22m[39m    open([38;2;239;83;80m![39mMatched[38;2;206;147;216m::Function[39m, [38;2;239;83;80m![39mMatched[38;2;206;147;216m::Type[39m, [38;2;239;83;80m![39mMatched[38;2;206;147;216m::Any...[39m) where          [2m[31m│[22m[39m
    [2m[31m│[22m[39m  T<[38;2;255;167;38m:TranscodingStreams[39m.TranscodingStream                                     [2m[31m│[22m[39m
    [2m[31m│[22m[39m     @ TranscodingStreams [38;2;239;83;80m~[39m[38;2;239;83;80m/[39m.julia[38;2;239;83;80m/[39mpackages[38;2;239;83;80m/[39mTranscodingStreams[38;2;239;83;80m/[39m[38;2;144;202;249m2[39mMcN2[38;2;239;83;80m/[39msrc[38;2;239;83;80m/[39ms    [2m[31m│[22m[39m
    [2m[31m│[22m[39m  tream.jl:[38;2;144;202;249m171[39m                                                                [2m[31m│[22m[39m
    [2m[31m│[22m[39m    open([38;2;239;83;80m![39mMatched[38;2;206;147;216m::Function[39m, [38;2;239;83;80m![39mMatched[38;2;206;147;216m::Type[39m, [38;2;239;83;80m![39mMatched[38;2;206;147;216m::Any...[39m; kwargs...)     [2m[31m│[22m[39m
    [2m[31m│[22m[39m  where T<[38;2;255;167;38m:BioGenerics[39m.IO.AbstractFormattedIO                                 [2m[31m│[22m[39m
    [2m[31m│[22m[39m     @ BioGenerics [38;2;239;83;80m~[39m[38;2;239;83;80m/[39m.julia[38;2;239;83;80m/[39mpackages[38;2;239;83;80m/[39mBioGenerics[38;2;239;83;80m/[39m[38;2;144;202;249m1[39md69j[38;2;239;83;80m/[39msrc[38;2;239;83;80m/[39mIO.jl:[38;2;144;202;249m54[39m           [2m[31m│[22m[39m
    [2m[31m│[22m[39m    ...                                                                       [2m[31m│[22m[39m
    [2m[31m│[22m[39m                                                                              [2m[31m│[22m[39m
    [2m[31m│[22m[39m                                                                              [2m[31m│[22m[39m
    [0m[2m[31m╰──────────────────────────────────────────────────────────────────────────────╯[22m[39m[0m[0m

## The solution

Instead, you must open the IO stream, iterate through the
`FASTA.Record`s (`FASTARecord`s) while the Reader has control of the
underlying IO, and *then* close it.

``` julia
begin
    reader = FASTAReader(open("example.fasta"))
    record = first(reader)
    println(typeof(record))
    @show record # using FASTX.jl Base.show(io::IO, record::Record) method
    @show sequence(record) # field accessor for FASTARecord
    close(reader)
end
```

    FASTX.FASTA.Record
    record = FASTX.FASTA.Record:
      description: "human"
         sequence: "ACCGTGATGTAGAGACCACGGGCCC"
    sequence(record) = "ACCGTGATGTAGAGACCACGGGCCC"

This is why the `do` block syntax works..

``` julia
open(FASTAReader, "example.fasta") do reader
    for record in reader
        @show record
    end
end
```

    record = FASTX.FASTA.Record:
      description: "human"
         sequence: "ACCGTGATGTAGAGACCACGGGCCC"
    record = FASTX.FASTA.Record:
      description: "mouse"
         sequence: "CCCAGTGTGTAACA"
    record = FASTX.FASTA.Record:
      description: "cat"
         sequence: "AGTGTGTGTTGTGCCCG"

You’re dispatching on the `open(f::Function, args...; kwargs...)` method
twice:

1.  You dispatch `Base.open` as `open(f::Function, args...; kwargs...)`
    with the `do` block syntax which passes an anonymous function (the
    control flow `for` loop) back as the first argument.

2.  Next, the anonymous function is applied to dispactching `Base.open`
    on the `args...; kwargs...` part, for which the first argument is
    another function, the `FASTAReader` constructor. So you end up
    dipatching the same `open(f::Function, args...; kwargs...)` method
    again.

3.  Finally, that `FASTAReader` constructor is applied to dispatching
    `Base.open` (in the same manner as above) on the
    `args...; kwargs...` part, which is now just `open([file])`, and the
    `FASTAReader` takes control of that underlying IO stream.

I’ve tried to further demonstrate this by creating an anonymous iterator
instead:

``` julia
open(
    reader -> for record in reader
        @show record
    end,
    FASTAReader,
    "example.fasta"
)
```

    record = FASTX.FASTA.Record:
      description: "human"
         sequence: "ACCGTGATGTAGAGACCACGGGCCC"
    record = FASTX.FASTA.Record:
      description: "mouse"
         sequence: "CCCAGTGTGTAACA"
    record = FASTX.FASTA.Record:
      description: "cat"
         sequence: "AGTGTGTGTTGTGCCCG"

## Summary

So to put it all together, you might do something like this:

``` julia
begin
    records = Vector{FASTARecord}()

    open(FASTAReader, "example.fasta") do reader
        for record in reader
            push!(records, record)
        end
    end

    records
end
```

    ╭─────────────────────────────────────────╮
    │                                         │
    │     (1)   >human                        │
    │           ACCGTGATGTAGAGACCACGGGCCC     │
    │     (2)   >mouse                        │
    │           CCCAGTGTGTAACA                │
    │     (3)   >cat                          │
    │           AGTGTGTGTTGTGCCCG             │
    │                                         │
    │                                         │
    ╰───────────────────────────── 3 items ───╯

Now we can access each record as a vector element:

``` julia
[1:length(records) .=> description.(records)]
```

    ╭────────────────────────────────────────────────────────────────────╮
    │                                                                    │
    │     (1)   Pair{Int64, StringViews.StringView{SubArray{UInt8, 1, Vector, Tuple, true} }[1 => "human", 2 => "mouse", 3 => "cat"]...... │
    │                                                                    │
    │                                                                    │
    │                                                                    │
    │                                                                    │
    ╰──────────────────────────────────────────────────────── 1 items ───╯

``` julia
records[1]
```

    FASTX.FASTA.Record:
      description: "human"
         sequence: "ACCGTGATGTAGAGACCACGGGCCC"

------------------------------------------------------------------------

## Closing & Footnotes

I hope this helps other folks who might be struggling to wrap their
minds around what is happening when they read FASTX files with this nice
BioJulia package.

[^1]: View the package on GitHub: <https://github.com/BioJulia/FASTX.jl>
    and also find the documentation here:
    <https://docs.juliahub.com/FASTX/ZwJmk/2.1.0/>.

[^2]: https://docs.juliahub.com/FASTX/ZwJmk/2.1.0/files/
