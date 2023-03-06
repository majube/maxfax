"""
Implements a data structure that gets used to decode an ASCII fax bitstream.
"""

module LookupTree

include("constants.jl")

using .FaxConstants: EOL

export Node, constructlookuptree

mutable struct Node
    const value::Union{Nothing,String}
    const lastbit::Union{Nothing,Char}
    const runlength::Union{Nothing,Int64}
    children::Union{Nothing,Array{Union{Node,Missing}}}
end

function constructlookuptree(makeupcwsdict, termcwsdict)
    rl2cw = merge(termcwsdict, makeupcwsdict)
    cw2rl = Dict(v => k for (k, v) in rl2cw)
    #runlength -1 for EOL
    cw2rl[EOL] = -1

    codewords = sort(collect(keys(cw2rl)), by=length)
    root = Node(nothing, nothing, nothing, Array{Union{Node,Missing},1}(missing, 2))

    for codeword in codewords
        parent = root

        for (i, bit) in enumerate(codeword)
            #add leaf node if at end of codeword
            if i == lastindex(codeword)
                parent.children[bit == '0' ? 1 : 2] = Node(
                    codeword,
                    bit,
                    cw2rl[codeword],
                    nothing
                )

                #intermediate node
            else
                #add child if it doesn't exist yet
                if ismissing(parent.children[bit == '0' ? 1 : 2])
                    newnode = Node(
                        codeword[1:i],
                        bit,
                        nothing,
                        Array{Union{Node,Missing},1}(missing, 2)
                    )
                    parent.children[bit == '0' ? 1 : 2] = newnode
                    parent = newnode

                else
                    parent = parent.children[bit == '0' ? 1 : 2]
                end
            end
        end
    end

    #TODO: implement FILLBIT in tree (child->parent loop for left-most node)

    return root
end

end