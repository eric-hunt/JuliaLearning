### A Pluto.jl notebook ###
# v0.19.26

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ a6ed9bac-ad3f-40a1-bac6-1cf95885cb0e
using FASTX

# ╔═╡ fa2affbc-47f0-46da-8d82-91378347d1a7
using PlutoUI

# ╔═╡ 8dd66df4-0544-11ee-3b86-4109fad922c1
md"""
# Reading FASTA and FASTQ files in Julia
"""

# ╔═╡ df9b1215-31d0-4a03-b93c-b51df75ebfa2
md"""
## Package dependencies
"""

# ╔═╡ 739286df-c3fb-481f-95ca-019d57e958ba
md"""
## The problem

*Uhh.. well.. my problem. Someone out there understands all this perfectly.* 😆

Using the `FASTA`/`FASTQ.Reader` structs from FASTX.jl[^1], which wrap around an IO, has been confusing me -- particularly because the `do` block syntax makes things less straighforward to immediately understand.

Below is a typical `do` block for using `Base.open` by dispatching the method:

```
open(f::Function, args...; kwargs...)
```

The docs for this method state:

>Apply the function f to the result of open(args...; kwargs...) and close the resulting file descriptor upon completion.

So let's open an example FASTA file and see what we get:
"""

# ╔═╡ 176f04d3-a43f-424c-9563-1a9a027f8716
example_file = open("example.fasta", "r") do io
	FASTX.FASTA.Reader(io)
end

# ╔═╡ 596cc91f-0db7-488f-9cef-f89e94bbdf0e
md"""
We get a FASTX.FASTA.Reader with a `NoopStream` IO stream type. Sweet. I'd love to tell you exactly what this means, but I don't really know. I think it means that the IO stream was present, but the `do` block dispatch of the `Base.open` method shown above closed it before we really did anything with it, so now we have a placeholder "no-operation" stream that essentially produces nothing.

Looking into the FASTX.jl docs[^2] they say:

>Readers and writers take control over the underlying IO, and manipulating the IO underneath a Reader/Writer, e.g. by flushing or closing it, cause them to behave in an undefined manner.
>
>Closing readers/writers closes the underlying IO. Because they carry their own buffers, it's important to remember to close writers in particular, else the results may not be fully written to the file.

> Readers are iterables of `Record`.

So can we do something like this..?
"""

# ╔═╡ f8c80b9b-30df-4794-9e91-fe61d9838f02
begin
	for record in example_file
		@show record
	end
end

# ╔═╡ 31b3283d-b8fd-40fc-bf1e-92cc0610568e
md"""
..alas, no, because the Reader IO was closed and there aren't any records in an no-op stream. 🫥

Somewhat related -- and also probably indicative of my technical understanding or lack thereof -- you can't reopen or initiate the no-op stream to iterate through records because, perhaps unsurprisingly, there is no `open` method to dispatch on type `::FASTX.FASTA.Reader{TranscodingStreams.NoopStream{IOStream}}`.
"""

# ╔═╡ ee5a2845-bd7c-4cca-a152-bbc92effd275
begin
	io = open(example_file)
	for record in io
		@show record
	end
	close(io)
end

# ╔═╡ e54e5d05-200b-4e31-a93c-d5be5cc6bd1e
md"""
## The solution

Instead, you must open the IO stream, iterate through the `FASTA.Record`s while the Reader has control of the underlying IO, and *then* close it.
"""

# ╔═╡ 54626de0-3880-4063-a1fa-f4f64937a5a2
begin
	reader = FASTAReader(open("example.fasta"))
	record = first(reader)
	println(typeof(record))
	@show record # using FASTX.jl Base.show(io::IO, record::Record) method
	@show sequence(record) # field accessor for FASTX.FASTA.Record
	close(reader)
end

# ╔═╡ c2b5c5d3-9f1f-48a6-ace1-8c1388aa4731
md"""
This is why the `do` block syntax works..
"""

# ╔═╡ 37f95c3a-606b-49cd-8f9a-649d834da0a8
open(FASTX.FASTA.Reader, "example.fasta") do reader
	for record in reader
		@show record
	end
end

# ╔═╡ 21a465db-74b1-4cd4-a3da-6e1d09ae0d3c
md"""
You're dispatching on the `open(f::Function, args...; kwargs...)` method twice:

1. You dispatch `Base.open` as `open(f::Function, args...; kwargs...)` with the `do` block syntax which passes an anonymous function (the control flow `for` loop) back as the first argument.

2. Next, the anonymous function is applied to dispactching `Base.open` on the `args...; kwargs...` part, for which the first argument is another function, the `FASTAReader` constructor. So you end up dipatching the same `open(f::Function, args...; kwargs...)` method again.

3. Finally, that `FASTAReader` constructor is applied to dispatching `Base.open` (in the same manner as above) on the `args...; kwargs...` part, which is now just `open([file])`, and the `FASTAReader` takes control of that underlying IO stream.

I've tried to further demonstrate this by creating an anonymous iterator instead:
"""

# ╔═╡ 92e3b8eb-e085-45db-a02d-da056b881726
open(
	reader -> for record in reader
				@show record
	end,
	FASTX.FASTA.Reader,
	"example.fasta"
)

# ╔═╡ 2ffe8d48-4e3a-4c12-87fb-e3d3775ca04a
md"""
---
"""

# ╔═╡ 833e712f-c6f1-4330-9328-3aecb97658fa
md"""
## Summary

So to put it all together, you might do something like this:
"""

# ╔═╡ 94ba7d8b-bf74-4411-b5ca-8a50e741a882
begin
	records = Vector{FASTARecord}()
	
	open(FASTX.FASTA.Reader, "example.fasta") do reader
		for record in reader
			push!(records, record)
		end
	end
	
	records
end

# ╔═╡ 3efb4df5-b683-4b24-bddb-bf2cf1023918
md"""
Now we can access each record as a vector element:
"""

# ╔═╡ ad922f9e-2122-4a4a-8b1a-593c22cda617
typeof(records)

# ╔═╡ ba27744b-b927-42bc-b34c-a2196432ecd9
options = [1:length(records) .=> description.(records)]

# ╔═╡ 2dc434c7-595c-4537-b18d-2fbf30ad5b32
md"""
Select a record:
"""

# ╔═╡ c55835b7-0872-4e39-9827-e937d49a1e91
@bind x Select(options...)

# ╔═╡ f72692a3-7d48-469b-99a8-8bc45750b798
records[x]

# ╔═╡ d44ed98b-b600-4933-9abf-1baadd8e8604
md"""
---
## Closing & Footnotes

I hope this helps other folks who might be struggling to wrap their minds around what is happening when they read FASTX files with this nice BioJulia package.

[^1]: View the package on GitHub: [https://github.com/BioJulia/FASTX.jl](https://github.com/BioJulia/FASTX.jl) and also find the documentation here: [https://docs.juliahub.com/FASTX/ZwJmk/2.1.0/](https://docs.juliahub.com/FASTX/ZwJmk/2.1.0/).


[^2]: https://docs.juliahub.com/FASTX/ZwJmk/2.1.0/files/
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
FASTX = "c2308a5c-f048-11e8-3e8a-31650f418d12"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
FASTX = "~2.1.0"
PlutoUI = "~0.7.51"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0"
manifest_format = "2.0"
project_hash = "2cb3b23c116ea4ae9f0ffe3938613b46d9686dfb"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Automa]]
deps = ["Printf", "ScanByte", "TranscodingStreams"]
git-tree-sha1 = "d50976f217489ce799e366d9561d56a98a30d7fe"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "0.8.2"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BioGenerics]]
deps = ["TranscodingStreams"]
git-tree-sha1 = "0b581906418b93231d391b5dd78831fdc2da0c82"
uuid = "47718e42-2ac5-11e9-14af-e5595289c2ea"
version = "0.1.2"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FASTX]]
deps = ["Automa", "BioGenerics", "PrecompileTools", "ScanByte", "StringViews", "TranscodingStreams"]
git-tree-sha1 = "310745fd82f021e85d0fb7f10632ea0c7eceeff6"
uuid = "c2308a5c-f048-11e8-3e8a-31650f418d12"
version = "2.1.0"

    [deps.FASTX.extensions]
    BioSequencesExt = "BioSequences"

    [deps.FASTX.weakdeps]
    BioSequences = "7e6ae17a-c86d-528c-b3b9-7f778a29fe59"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "d75853a0bdbfb1ac815478bacd89cd27b550ace6"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.3"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "a5aef8d4a6e8d81f171b2bd4be5265b01384c74c"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.10"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "b478a748be27bd2f2c73a7690da219d0844db305"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.51"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "9673d39decc5feece56ef3940e5dafba15ba0f81"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.1.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "0e270732477b9e551d884e6b07e23bb2ec947790"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.4.5"

[[deps.ScanByte]]
deps = ["Libdl", "SIMD"]
git-tree-sha1 = "2436b15f376005e8790e318329560dcc67188e84"
uuid = "7b38b023-a4d7-4c5e-8d43-3f3097f304eb"
version = "0.3.3"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StringViews]]
git-tree-sha1 = "dcb71a103d35d73a9354e646e392a79500bc35dc"
uuid = "354b36f9-a18e-4713-926e-db85100087ba"
version = "1.3.1"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.7.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─8dd66df4-0544-11ee-3b86-4109fad922c1
# ╟─df9b1215-31d0-4a03-b93c-b51df75ebfa2
# ╠═a6ed9bac-ad3f-40a1-bac6-1cf95885cb0e
# ╠═739286df-c3fb-481f-95ca-019d57e958ba
# ╠═176f04d3-a43f-424c-9563-1a9a027f8716
# ╠═596cc91f-0db7-488f-9cef-f89e94bbdf0e
# ╠═f8c80b9b-30df-4794-9e91-fe61d9838f02
# ╠═31b3283d-b8fd-40fc-bf1e-92cc0610568e
# ╠═ee5a2845-bd7c-4cca-a152-bbc92effd275
# ╠═e54e5d05-200b-4e31-a93c-d5be5cc6bd1e
# ╠═54626de0-3880-4063-a1fa-f4f64937a5a2
# ╠═c2b5c5d3-9f1f-48a6-ace1-8c1388aa4731
# ╠═37f95c3a-606b-49cd-8f9a-649d834da0a8
# ╠═21a465db-74b1-4cd4-a3da-6e1d09ae0d3c
# ╠═92e3b8eb-e085-45db-a02d-da056b881726
# ╟─2ffe8d48-4e3a-4c12-87fb-e3d3775ca04a
# ╠═833e712f-c6f1-4330-9328-3aecb97658fa
# ╠═94ba7d8b-bf74-4411-b5ca-8a50e741a882
# ╠═3efb4df5-b683-4b24-bddb-bf2cf1023918
# ╟─ad922f9e-2122-4a4a-8b1a-593c22cda617
# ╠═fa2affbc-47f0-46da-8d82-91378347d1a7
# ╠═ba27744b-b927-42bc-b34c-a2196432ecd9
# ╟─2dc434c7-595c-4537-b18d-2fbf30ad5b32
# ╟─c55835b7-0872-4e39-9827-e937d49a1e91
# ╠═f72692a3-7d48-469b-99a8-8bc45750b798
# ╠═d44ed98b-b600-4933-9abf-1baadd8e8604
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
