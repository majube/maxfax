"""
Basic implementation of decoding an ASCII bitstream encoded according to ITU T.4 into an image.
Will decode a wav file after demodulation is implemented.
"""

include("constants.jl")
include("tree.jl")

using .FaxConstants
using .LookupTree
using Images

function readdata(fn)
    open(fn, "r") do io
        return read(fn, String)
    end
end

function decodedata(datastr)
    whitetree = constructlookuptree(TERMWHITE, MAKEUPWHITE)
    blacktree = constructlookuptree(TERMBLACK, MAKEUPBLACK)

    EOLcounter = 0
    colours = Char[]
    runlengths = Int[]

    #start with white
    currentnode = whitetree
    currentcolour = 'W'

    for bit in datastr
        nextnode = currentnode.children[bit == '0' ? 1 : 2]

        #next node is an intermediate node
        if nextnode.children !== nothing
            currentnode = nextnode

        #next node is a leaf node
        else
            #save current colour and runlength
            push!(colours, currentcolour)
            push!(runlengths, nextnode.runlength)

            #back to root if make-up cw
            if nextnode.runlength >= 64
                if currentcolour == 'W'
                    currentnode = whitetree
                else
                    currentnode = blacktree
                end

            #terminating cw
            else
                #if the cw is EOL, increment EOLcounter by 1; break if ==7 (EOL + RTC)
                if nextnode.runlength == -1
                    EOLcounter += 1
                    EOLcounter == 7 && break
                else
                    EOLcounter = 0
                end

                #switch to white if the current colour is black or cw is EOL
                if currentcolour == 'B' || nextnode.runlength == -1
                    currentnode = whitetree
                    currentcolour = 'W'

                #else switch to black if current colour is white
                else
                    currentnode = blacktree
                    currentcolour = 'B'
                end
            end
        end
    end

    return (colours, runlengths)
end

function constructimage(colours, runlengths)
    m, currentline = [Int[]], Int[]

    for (i, (colour, runlength)) in enumerate(zip(colours, runlengths))
        #break if RTC
        if runlength == -1 && allequal(runlengths[i:i+6])
            push!(m, currentline)
            break

        elseif runlength == -1
            push!(m, currentline)
            currentline = Int[]

        else
            append!(currentline, fill(colour == 'B' ? 0 : 1, runlength))
        end
    end

    #hacky
    m = m[3:lastindex(m)]

    return Gray.(transpose(reduce(hcat, m)))
end

function demodulate(wav)
    #TODO implement
end

datastr = readdata(ARGS[1])
(colours, runlengths) = decodedata(datastr)
img = constructimage(colours, runlengths)
save("received.png", img)