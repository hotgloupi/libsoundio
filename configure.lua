
local major, minor, patch = 1, 0, 3
local version_string = "1.0.3"

local function gen_config_h(build, libs)
    local dest_include_dir = build:directory() / "include" / "soundio"
    build:fs():create_directories(dest_include_dir)
    local str = string.format([[
#ifndef SOUNDIO_CONFIG_H
# define SOUNDIO_CONFIG_H
# define SOUNDIO_VERSION_MAJOR %i
# define SOUNDIO_VERSION_MINOR %i
# define SOUNDIO_VERSION_PATCH %i
# define SOUNDIO_VERSION_STRING "%i.%i.%i"
]], major, minor, patch, major, minor, patch)
    for _, lib in pairs(libs) do
        str = str .. "# define SOUNDIO_HAVE_" .. lib.name:upper() .. '\n'
    end
    str = str .. '#endif\n'
    local path = dest_include_dir / "config.h"
    local old = nil
    if path:exists() then
        local config_h = assert(io.open(tostring(path), 'r'))
        old = config_h:read("*all")
        config_h:close()
    end
    if str ~= old then
        local config_h = assert(io.open(tostring(path), 'w'))
        config_h:write(str)
        config_h:close()
    end
    return dest_include_dir
end

return function(build, args)
    args = args or {}
    local compiler = args.compiler or require('configure.lang.cxx.compiler').find{
        build = build,
    }

    local sources = {
        "src/soundio.c",
        "src/util.c",
        "src/os.c",
        "src/dummy.c",
        "src/channel_layout.c",
        "src/ring_buffer.c",
    }

    local lib_names = {'alsa',}-- 'pulseaudio', 'jack', 'coreaudio', 'wasapi'}
    local libs = {}
    for _, name in ipairs(lib_names) do
        local lib = nil
        local err = nil
        if args[name] ~= nil then
            lib = args[name]
        else
            lib, err = try(
                require('configure.modules')[name].find,
                {
                    build = build,
                    compiler = compiler,
                }
            )
        end
        if lib ~= nil then
            table.append(libs, lib)
            table.append(sources, 'src/' .. name .. '.c')
        else
            print(err)
        end
    end

    local dir = gen_config_h(build, libs)


    --local has_jack = compiler:has_include('jack/jack.h')
    --local has_pulse_audio = compiler:has_include('pulse/pulseaudio.h')
    --local has_alsa = compiler:has_include("alsa/asoundlib.h")
    --build:status("JACK found:", has_jack)
    --build:status("PulseAudio found:", has_pulse_audio)
    --build:status("has alsa", has_alsa)

    local include_directories = {
        dir,
        build:project_directory()
    }

    local standard = 'c11'
    if compiler.lang == 'c++' then standard = 'c++11' end

    return compiler:link_static_library{
        name = 'soundio',
        sources = sources,
        include_directories = include_directories,
        standard = standard,
        libraries = libs,
        defines = {
            {'_POSIX_C_SOURCE', '200809L'},
        }
    }
end
