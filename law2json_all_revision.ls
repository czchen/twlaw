require! {optimist, fs, mkdirp}
require! './lib/parse'

fixup = -> it.replace /　/g, ' '
fixBr = -> it - /\s*<br>\s*/ig - /\s+$/

zhnumber = <[○ 一 二 三 四 五 六 七 八 九 十]>
zhmap = {[c, i] for c, i in zhnumber}
parseZHNumber = ->
    it .= replace /零/g, '○'
    it .= replace /百$/g, '○○'
    it .= replace /百/, ''
    if it.0 is \十
        l = it.length
        return 10 if l is 1
        return 10 + parseZHNumber it.slice 1
    if it[*-1] is \十
        return 10 * parseZHNumber it.slice 0, it.length-1
    res = 0
    for c in it when c isnt \十
        res *= 10
        res += zhmap[c]
    res

parseDate = ->
    m = it.match /(.*)年(.*)月(.*)日/
    return [parseZHNumber(m.1) + 1911, parseZHNumber(m.2), parseZHNumber(m.3)] * \.

lawStatus = (dir) ->
    for basename in <[ 廢止 停止適用 ]>
        if fs.existsSync "#dir/#basename.html"
            return basename
    return if fs.existsSync "#dir/全文.html" then \實施 else \未知

objToSortedArray = (obj) ->
    keys = for key, _ of obj
        key
    keys.sort (a, b) -> a - b
    x = for key in keys
        obj[key]
    return x

parseHTML = (lawdir) ->
    law =
        article: {}
    for file in fs.readdirSync lawdir
        if /\d+\.htm/ != file
            continue
        console.log "Process #lawdir/#file"
        html = fs.readFileSync "#lawdir/#file"

        var name, lyID, ver, article, paragraph, subparagraph, item

        for line in html / '\n'
            match line
            | /法編號:(\d+)\s+版本:(\d+)/
                lyID = that.1
                ver = that.2
                law.lyID = lyID
            | /<FONT COLOR=blue SIZE=5>([^(]+)/
                name = that.1
                law.name = name
            | /<font color=8000ff>第(.*)條(?:之(.*))?/
                major = that.1
                minor = that.3

                major = parseZHNumber major
                minor = if minor => parseZHNumber minor else void

                # Accident hit some sentenance else
                if not major
                    break

                article = if minor => "#{major}-#{minor}" else "#{major}"
                paragraph = 0

                law.article["#article"] =
                    paragraph: {}

            # http://law.moj.gov.tw/LawClass/LawSearchNo.aspx?PC=A0030133&DF=&SNo=8,9

            | /^(　　（([一二三四五六七八九十]+).*)<br>/
                item = parseZHNumber that.2
                law.article["#article"].paragraph["#paragraph"].subparagraph["#subparagraph"].item["#item"] =
                    content: that.1

            | /^(　　([一二三四五六七八九十]+)、.*)<br>/
                subparagraph = parseZHNumber that.2
                law.article["#article"].paragraph["#paragraph"].subparagraph["#subparagraph"] =
                        item:
                            \0 :
                                content: that.1

            | /^(　　.*)<br>/
                ++paragraph

                law.article["#article"] =
                    paragraph:
                        "#paragraph":
                            subparagraph:
                                \0 :
                                    item:
                                        \0 :
                                            content: that.1

    law

{outdir} = optimist.argv
for lawdir in optimist.argv._
    try
        m = lawdir.match /([^/]+\/[^/]+)\/?$/
        dir = "#outdir/#{m.1}"

        mkdirp.sync dir
        law = parseHTML lawdir
        fs.writeFileSync "#dir/law.json", JSON.stringify law, '', 4
    catch
        console.error "ERROR: #lawdir (#e)"
