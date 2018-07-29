#
# Static site generator for Tensor Network website
# 

include("bibtex.jl")

#
# Process citations
# 
function processCitations(html::String)::Tuple{String,Dict{String,Int}}
  cite_re = r"\\cite{(.+?)}"
  citenums = Dict{String,Int}()
  res = String("")
  pos = 1
  match = false
  counter = 1
  for m in eachmatch(cite_re,html)
    match = true
    res *= html[pos:m.offset-1]
    name = convert(String,m.captures[1])
    if haskey(citenums,name)
      num = citenums[name]
    else
      citenums[name] = counter
      num = counter
      counter += 1
    end
    res *= "<a class=\"citation\" href=\"#$(name)_$(num)\">[$num]</a>"
    pos = m.offset+length(m.match)
  end
  if !match 
    return (html,citenums)
  else
    res *= html[pos:end]
  end
  return (res,citenums)
end

#
# Process MathJax
# 
function processMathJax(html::String)
  imj_re = r"(\@\@.+?\@\@)"s
  res = ""
  pos = 1
  match = false
  for m in eachmatch(imj_re,html)
    match = true
    res *= html[pos:m.offset-1]
    res *= "\n\n<div>"*m.captures[1]*"</div>\n\n"
    pos = m.offset+length(m.match)
  end
  if !match 
    return html 
  else
    res *= html[pos:end]
  end
  return res
end

#
# Process wiki-style links
# 
function processWikiLinks(html::String)
  link_re = r"\[\[(.+?)\|(.*?)\]\]"
  res = ""
  pos = 1
  match = false
  for m in eachmatch(link_re,html)
    match = true
    res *= html[pos:m.offset-1]
    if isdir("src/"*m.captures[2])
      res *= "["*m.captures[1]*"](/"*m.captures[2]*")"
    elseif isfile("src/"*m.captures[2]*".md")
      res *= "["*m.captures[1]*"](/"*m.captures[2]*".html)"
    else
      res *= "["*m.captures[1]*"](unknown_file)"
    end
    pos = m.offset+length(m.match)
  end
  if !match 
    return html 
  else
    res *= html[pos:end]
  end
  return res
end

#
# Process arxiv preprint links
# 
function processArxivLinks(html::String)
  link_re = r"arxiv:\W*?(\d+?\.\d+)"
  res = ""
  pos = 1
  match = false
  for m in eachmatch(link_re,html)
    match = true
    res *= html[pos:m.offset-1]
    res *= "arxiv:["*m.captures[1]*"](https://arxiv.org/abs/"*m.captures[1]*")"
    pos = m.offset+length(m.match)
  end
  if !match 
    return html 
  else
    res *= html[pos:end]
  end
  return res
end

function printEditFooter(of::IOStream,fname::String)
  template_edit_footer = open("template_edit_footer.html") do file readstring(file) end
  link = "https://github.com/TensorNetwork/tensornetwork.org/edit/master/"*fname
  out = replace(template_edit_footer,r"{github_link}",link)
  #@show out
  print(of,out)
end

function generateRefs(citenums,btentries)
  keys = Array{String,1}(length(citenums))
  for (k,v) in citenums
    keys[v] = k
  end
  rhtml = "## References\n"
  for (n,k) in enumerate(keys)
    if haskey(btentries,k)
      bt = btentries[k]
      rhtml *= "$n. <a name=\"$(bt.name)_$(n)\"></a>"*convertToMD(bt)
      rhtml *= "\n"
    end
  end
  return rhtml
end

header_prenav = open("header_prenav.html") do file readstring(file) end
header_postnav = open("header_postnav.html") do file readstring(file) end
footer = open("footer.html") do file readstring(file) end

idir = "src"
odir = "../tensornetwork.org"
run(`mkdir -p $odir`)
run(`cp -r css $odir/`)
run(`cp -r images $odir/`)

for (root,dirs,files) in walkdir(idir)
  curri = idir * root[4:end]
  curro = odir * root[4:end]
  for d in dirs
    run(`mkdir -p $curro/$d`)
  end
  for f in files
    (f[1]=='.') && continue
    (base,ext) = split(f,".")
    ifname = curri*"/"*f
    if ext == "md"
      ofname = curro*"/"*base*".html"
      mdstring = readstring(`cat $ifname`)
      mdstring = processMathJax(mdstring)
      mdstring = processWikiLinks(mdstring)

      (mdstring,citenums) = processCitations(mdstring)
      btfile = curri*"/"*base*".bib"
      if isfile(btfile)
        bt = parseBibTex(btfile)
        refmd = generateRefs(citenums,bt)
        mdstring *= refmd
      end

      mdstring = processArxivLinks(mdstring)

      open("_tmp_file.md","w") do tf
        print(tf,mdstring)
      end
      #html = readstring(`cmark _tmp_file.md`)
      html = readstring(`python2.7 -m markdown _tmp_file.md`)
      open(ofname,"w") do of
        print(of,header_prenav)
        print(of,header_postnav)
        print(of,html)
        printEditFooter(of,ifname)
        print(of,footer)
      end
      run(`rm -f _tmp_file.md`)
    elseif ext == "png" || ext == "jpg"
      run(`cp $ifname $(curro*"/"*f)`)
    end
  end
end

