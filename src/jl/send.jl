"""
Basic implementation of reading in an image, converting it to B/W,
run-length encoding it according to ITU T.4, and saving it as ASCII text.
Will encode into a wav file after modulation is implemented.
"""

include("constants.jl")

using .FaxConstants
using Images, FileIO, TestImages

function loadimg(imgpath)
    return load(imgpath)
end

function tograyscale(rgbimg)
    return Gray.(rgbimg)
end

function findmakeuplength(runlength)
    for makeuplength in MAKEUPLENGTHS
        if makeuplength <= runlength
            return makeuplength
        end
    end
end

function rltocodewords(colour, runlength)
    if runlength <= 63
        if colour == 'W'
            return TERMWHITE[runlength]
        else
            return TERMBLACK[runlength]
        end

    else
        makeuplength = findmakeuplength(runlength)
        termlength = runlength - makeuplength

        if colour == 'W'
            return join([MAKEUPWHITE[makeuplength], TERMWHITE[termlength]])
        else
            return join([MAKEUPBLACK[makeuplength], TERMBLACK[termlength]])
        end
    end
end

function encodeimage(grayimg)
    (nrows, ncols) = size(grayimg)

    #initial run colour white of length zero
    currentruncolours = fill('W', nrows)
    currentrunlengths = zeros(Int, nrows)

    encodedlines = [String[] for _ in 1:nrows]
    #first scanline starts with EOL
    push!(encodedlines[1], EOL)

    #scan column-wise (unlike real faxes but faster for how Julia stores matrices)
    for j in 1:ncols
        for i in 1:nrows
            bwval = grayimg[i, j] >= BWTHRESHOLD ? 'W' : 'B'

            if currentruncolours[i] == bwval
                currentrunlengths[i] += 1

            else
                push!(
                    encodedlines[i],
                    rltocodewords(
                        currentruncolours[i],
                        currentrunlengths[i]
                    )
                )

                currentruncolours[i] = bwval
                currentrunlengths[i] = 1
            end
        end
    end

    #TODO: fill out data lines with FILLBIT here if shorter than minimum length
    for i in 1:nrows
        push!(
            encodedlines[i],
            rltocodewords(
                currentruncolours[i],
                currentrunlengths[i]
            ),
            EOL
        )
    end

    #RTC at end of message
    push!(encodedlines[lastindex(encodedlines)], RTC)

    return join([join(encodedlines[i]) for i in 1:nrows])
end

function savebitstream(bitstream, fn)
    open(fn, "w") do io
        write(io, bitstream)
    end
end

function modulate(data)
    #TODO implement
end

img = testimage("morphology_test_512.tiff")
grayimg = tograyscale(img)
bitstream = encodeimage(grayimg)
savebitstream(bitstream, ARGS[1])