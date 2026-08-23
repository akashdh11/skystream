/*****************************************************************************
 * structures.hpp: LibVLC++ structures
 *****************************************************************************
 * Copyright © 2015 libvlcpp authors & VideoLAN
 *
 * Authors: Alexey Sokolov <alexey+vlc@asokolov.org>
 *          Hugo Beauzée-Luyssen <hugo@beauzee.fr>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifndef LIBVLC_CXX_STRUCTURES_H
#define LIBVLC_CXX_STRUCTURES_H

#include <string>

#include "common.hpp"
#include "Picture.hpp"

//FIXME:
//Should we make the constructors private again and implement our own vector allocator?

namespace VLC
{

///
/// \brief The ModuleDescription class describes a module
///
class ModuleDescription
{
public:
    ///
    /// \brief name Returns the module name
    ///
    const std::string& name() const
    {
        return m_name;
    }

    ///
    /// \brief shortname Returns the module short name
    ///
    const std::string& shortname() const
    {
        return m_shortname;
    }

    ///
    /// \brief longname returns the module long name
    ///
    const std::string& longname() const
    {
        return m_longname;
    }

    ///
    /// \brief help Returns a basic help string for this module
    ///
    const std::string& help() const
    {
        return m_help;
    }

    explicit ModuleDescription( libvlc_module_description_t* c )
    {
        if ( c->psz_name != nullptr )
            m_name = c->psz_name;
        if ( c->psz_shortname != nullptr )
            m_shortname = c->psz_shortname;
        if ( c->psz_longname != nullptr )
            m_longname = c->psz_longname;
        if ( c->psz_help != nullptr )
            m_help = c->psz_help;
    }

private:
    std::string m_name;
    std::string m_shortname;
    std::string m_longname;
    std::string m_help;
};

#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(4, 0, 0, 0)

///
/// \brief The MediaTrack class describes a track
///
class MediaTrack : public Internal<libvlc_media_track_t>
{
public:
    ///
    /// \brief The Type enum indicates the type of a track
    ///
    enum class Type
    {
        Unknown = libvlc_track_unknown,
        /// Audio track
        Audio = libvlc_track_audio,
        /// Video track
        Video = libvlc_track_video,
        /// Subtitle track (also called SPU sometimes)
        Subtitle = libvlc_track_text,
    };

    ///
    /// \brief The Orientation enum indicates the orientation of a video
    ///
    enum class Orientation
    {
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight,
        LeftTop,
        LeftBottom,
        RightTop,
        RightBottom
    };

    ///
    /// \brief The Projection enum indicates the projection of a video
    ///
    enum class Projection
    {
        Rectangular,
        /// 360 spherical
        Equirectangular,
        CubemapLayoutStandard = 0x100
    };

#if !defined(_MSC_VER) || _MSC_VER >= 1900
    constexpr static Type Unknown = Type::Unknown;
    constexpr static Type Audio = Type::Audio;
    constexpr static Type Video = Type::Video;
    constexpr static Type Subtitle = Type::Subtitle;
#else
    const static Type Unknown = Type::Unknown;
    const static Type Audio = Type::Audio;
    const static Type Video = Type::Video;
    const static Type Subtitle = Type::Subtitle;
#endif

    ///
    /// \brief codec Returns the codec as a fourcc
    ///
    /// This is the fourcc will use to select a codec, but it might be an
    /// interpretation of the original fourcc.
    /// \see originalFourCC()
    ///
    uint32_t codec() const
    {
        return m_obj->i_codec;
    }

    ///
    /// \brief originalFourCC Returns the fourcc as found in the file.
    ///
    /// VLC might chose to use a different fourcc internally.
    /// For instance, AVC1 & H264 fourcc are (almost?) identical. VLC would
    /// use H264 as the codec/fourcc, and store AVC1/H264 as the original fourcc
    ///
    uint32_t originalFourCC() const
    {
        return m_obj->i_original_fourcc;
    }

    ///
    /// \brief id The track internal ID.
    ///
    /// This can't be assume to grow one by one monotonically.
    ///
    int32_t id() const
    {
        return m_obj->i_id;
    }

    ///
    /// \brief type The track type
    ///
    /// \see MediaTrack::Type
    ///
    Type type() const
    {
        return static_cast<Type>( m_obj->i_type );
    }

    ///
    /// \brief profile This track profile
    ///
    /// This might or might not be set, depending on the codec.
    ///
    int32_t profile() const
    {
        return m_obj->i_profile;
    }

    ///
    /// \brief level This track level
    ///
    /// This might or might not be set, depending on the codec
    ///
    int32_t level() const
    {
        return m_obj->i_level;
    }

    ///
    /// \brief bitrate This track bitrate, in bytes per second
    /// \return
    ///
    uint32_t bitrate() const
    {
        return m_obj->i_bitrate;
    }

    ///
    /// \brief language This track language, if available.
    ///
    std::string language() const
    {
        return m_obj->psz_language ? m_obj->psz_language : "";
    }

    ///
    /// \brief description This track description
    ///
    std::string description() const
    {
        return m_obj->psz_description ? m_obj->psz_description : "";
    }

    ////////////////////////////////////////////////////////////////////////////
    /// Audio specific
    ////////////////////////////////////////////////////////////////////////////

    ///
    /// \brief channels This track number of channels
    ///
    uint32_t channels() const
    {
        assert( m_obj->i_type == libvlc_track_audio );
        return m_obj->audio->i_channels;
    }

    ///
    /// \brief rate This track samplerate, in hertz (Hz)
    ///
    uint32_t rate() const
    {
        assert( m_obj->i_type == libvlc_track_audio );
        return m_obj->audio->i_rate;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Video specific
    ////////////////////////////////////////////////////////////////////////////

    ///
    /// \brief height This track video height
    ///
    uint32_t height() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return m_obj->video->i_height;
    }

    ///
    /// \brief width This track video width
    ///
    uint32_t width() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return m_obj->video->i_width;
    }

    ///
    /// \brief sarNum This track aspect ratio numerator
    ///
    /// \see sarDen
    ///
    uint32_t sarNum() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return m_obj->video->i_sar_num;
    }

    ///
    /// \brief sarDen This track aspect ratio denominator
    ///
    /// \see sarNum
    ///
    uint32_t sarDen() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return m_obj->video->i_sar_den;
    }

    ///
    /// \brief fpsNum This track frame per second numerator
    ///
    /// \see fpsDen
    ///
    uint32_t fpsNum() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return m_obj->video->i_frame_rate_num;
    }

    ///
    /// \brief fpsDen This track frame per second denominator
    ///
    /// \see fpsNum
    ///
    uint32_t fpsDen() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return m_obj->video->i_frame_rate_den;
    }

    ///
    /// \brief Orientation
    ///
    /// \see orientation
    ///
    Orientation orientation() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return static_cast<Orientation>( m_obj->video->i_orientation );
    }

    ///
    /// \brief Projection
    ///
    /// \see projection
    ///
    Projection projection() const
    {
        assert( m_obj->i_type == libvlc_track_video );
        return static_cast<Projection>( m_obj->video->i_projection );
    }

    std::string idStr() const
    {
        return m_obj->psz_id ? m_obj->psz_id : "";
    }

    bool idStable() const
    {
        return m_obj->id_stable;
    }

    std::string name() const
    {
        return m_obj->psz_name ? m_obj->psz_name : "";
    }

    bool selected() const
    {
        return m_obj->selected;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Subtitles specific
    ////////////////////////////////////////////////////////////////////////////

    ///
    /// \brief encoding Subtitles text encoding
    ///
    std::string encoding() const
    {
        assert( m_obj->i_type == libvlc_track_text );
        return m_obj->subtitle->psz_encoding ? m_obj->subtitle->psz_encoding : "";
    }

    ///
    /// \brief MediaTrack Construct a libvlc_media_track_t representation
    /// \param c A valid media track
    ///
    /// \note The track will he held and released automatically.
    ///
    explicit MediaTrack(libvlc_media_track_t* c)
        : Internal{ libvlc_media_track_hold( c ), libvlc_media_track_release }
    {
    }
};

#else

///
/// \brief The MediaTrack class describes a track
///
class MediaTrack
{
public:
    ///
    /// \brief The Type enum indicates the type of a track
    ///
    enum class Type
    {
        Unknown = libvlc_track_unknown,
        /// Audio track
        Audio = libvlc_track_audio,
        /// Video track
        Video = libvlc_track_video,
        /// Subtitle track (also called SPU sometimes)
        Subtitle = libvlc_track_text,
    };

    ///
    /// \brief The Orientation enum indicates the orientation of a video
    ///
    enum class Orientation
    {
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight,
        LeftTop,
        LeftBottom,
        RightTop,
        RightBottom
    };

    ///
    /// \brief The Projection enum indicates the projection of a video
    ///
    enum class Projection
    {
        Rectangular,
        /// 360 spherical
        Equirectangular,
        CubemapLayoutStandard = 0x100
    };

#if !defined(_MSC_VER) || _MSC_VER >= 1900
    constexpr static Type Unknown = Type::Unknown;
    constexpr static Type Audio = Type::Audio;
    constexpr static Type Video = Type::Video;
    constexpr static Type Subtitle = Type::Subtitle;
#else
    const static Type Unknown = Type::Unknown;
    const static Type Audio = Type::Audio;
    const static Type Video = Type::Video;
    const static Type Subtitle = Type::Subtitle;
#endif

    ///
    /// \brief codec Returns the codec as a fourcc
    ///
    /// This is the fourcc will use to select a codec, but it might be an
    /// interpretation of the original fourcc.
    /// \see originalFourCC()
    ///
    uint32_t codec() const
    {
        return m_codec;
    }

    ///
    /// \brief originalFourCC Returns the fourcc as found in the file.
    ///
    /// VLC might chose to use a different fourcc internally.
    /// For instance, AVC1 & H264 fourcc are (almost?) identical. VLC would
    /// use H264 as the codec/fourcc, and store AVC1/H264 as the original fourcc
    ///
    uint32_t originalFourCC() const
    {
        return m_originalFourcc;
    }

    ///
    /// \brief id The track internal ID.
    ///
    /// This can't be assume to grow one by one monotonically.
    ///
    int32_t id() const
    {
        return m_id;
    }

    ///
    /// \brief type The track type
    ///
    /// \see MediaTrack::Type
    ///
    Type type() const
    {
        return m_type;
    }

    ///
    /// \brief profile This track profile
    ///
    /// This might or might not be set, depending on the codec.
    ///
    int32_t profile() const
    {
        return m_profile;
    }

    ///
    /// \brief level This track level
    ///
    /// This might or might not be set, depending on the codec
    ///
    int32_t level() const
    {
        return m_level;
    }

    ///
    /// \brief bitrate This track bitrate, in bytes per second
    /// \return
    ///
    uint32_t bitrate() const
    {
        return m_bitrate;
    }

    ///
    /// \brief language This track language, if available.
    ///
    const std::string& language() const
    {
        return m_language;
    }

    ///
    /// \brief description This track description
    ///
    const std::string& description() const
    {
        return m_description;
    }

    ////////////////////////////////////////////////////////////////////////////
    /// Audio specific
    ////////////////////////////////////////////////////////////////////////////

    ///
    /// \brief channels This track number of channels
    ///
    uint32_t channels() const
    {
        return m_channels;
    }

    ///
    /// \brief rate This track samplerate, in hertz (Hz)
    ///
    uint32_t rate() const
    {
        return m_rate;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Video specific
    ////////////////////////////////////////////////////////////////////////////

    ///
    /// \brief height This track video height
    ///
    uint32_t height() const
    {
        return m_height;
    }

    ///
    /// \brief width This track video width
    ///
    uint32_t width() const
    {
        return m_width;
    }

    ///
    /// \brief sarNum This track aspect ratio numerator
    ///
    /// \see sarDen
    ///
    uint32_t sarNum() const
    {
        return m_sarNum;
    }

    ///
    /// \brief sarDen This track aspect ratio denominator
    ///
    /// \see sarNum
    ///
    uint32_t sarDen() const
    {
        return m_sarDen;
    }

    ///
    /// \brief fpsNum This track frame per second numerator
    ///
    /// \see fpsDen
    ///
    uint32_t fpsNum() const
    {
        return m_fpsNum;
    }

    ///
    /// \brief fpsDen This track frame per second denominator
    ///
    /// \see fpsNum
    ///
    uint32_t fpsDen() const
    {
        return m_fpsDen;
    }

#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(3, 0, 0, 0)
    ///
    /// \brief Orientation
    ///
    /// \see orientation
    ///
    Orientation orientation() const
    {
        return m_orientation;
    }

    ///
    /// \brief Projection
    ///
    /// \see projection
    ///
    Projection projection() const
    {
        return m_projection;
    }
#endif

    ////////////////////////////////////////////////////////////////////////////
    // Subtitles specific
    ////////////////////////////////////////////////////////////////////////////

    ///
    /// \brief encoding Subtitles text encoding
    ///
    const std::string& encoding() const
    {
        return m_encoding;
    }

    explicit MediaTrack(libvlc_media_track_t* c)
        : m_codec( c->i_codec )
        , m_originalFourcc( c->i_original_fourcc )
        , m_id( c->i_id )
        , m_profile( c->i_profile )
        , m_level( c->i_level )
        , m_bitrate( c->i_bitrate )
    {
        if ( c->psz_language != nullptr )
            m_language = c->psz_language;
        if ( c->psz_description != nullptr )
            m_description = c->psz_description;
        switch ( c->i_type )
        {
            case libvlc_track_audio:
                m_type = Audio;
                m_channels = c->audio->i_channels;
                m_rate = c->audio->i_rate;
                break;
            case libvlc_track_video:
                m_type = Video;
                m_height = c->video->i_height;
                m_width = c->video->i_width;
                m_sarNum = c->video->i_sar_num;
                m_sarDen = c->video->i_sar_den;
                m_fpsNum = c->video->i_frame_rate_num;
                m_fpsDen = c->video->i_frame_rate_den;
#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(3, 0, 0, 0)
                m_orientation = static_cast<Orientation>( c->video->i_orientation );
                m_projection = static_cast<Projection>( c->video->i_projection );
#endif
                break;
            case libvlc_track_text:
                m_type = Subtitle;
                if ( c->subtitle->psz_encoding != nullptr )
                    m_encoding = c->subtitle->psz_encoding;
                break;
            case libvlc_track_unknown:
            default:
                m_type = Unknown;
                break;
        }
    }

private:
    uint32_t m_codec;
    uint32_t m_originalFourcc;
    uint32_t m_id;
    Type m_type;
    int32_t m_profile;
    int32_t m_level;
    uint32_t m_bitrate;
    std::string m_language;
    std::string m_description;
    // Audio
    uint32_t m_channels;
    uint32_t m_rate;
    // Video
    uint32_t m_height;
    uint32_t m_width;
    uint32_t m_sarNum;
    uint32_t m_sarDen;
    uint32_t m_fpsNum;
    uint32_t m_fpsDen;
#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(3, 0, 0, 0)
    Orientation m_orientation;
    Projection m_projection;
#endif
    // Subtitles
    std::string m_encoding;
};

#endif

///
/// \brief The AudioOutputDescription class describes an audio output module
///
class AudioOutputDescription
{
public:
    ///
    /// \brief name The module name
    ///
    const std::string& name() const
    {
        return m_name;
    }

    ///
    /// \brief description The module description
    ///
    const std::string& description() const
    {
        return m_description;
    }

    explicit AudioOutputDescription( libvlc_audio_output_t* c )
    {
        if ( c->psz_name != nullptr )
            m_name = c->psz_name;
        if ( c->psz_description != nullptr )
            m_description = c->psz_description;
    }

private:
    std::string m_name;
    std::string m_description;
};

///
/// \brief The AudioOutputDeviceDescription class describes an audio device, as seen
///         by an audio output module
///
class AudioOutputDeviceDescription
{
    public:
        /**< Device identifier string */
        const std::string& device() const
        {
            return m_device;
        }

        /**< User-friendly device description */
        const std::string& description() const
        {
            return m_description;
        }

        explicit AudioOutputDeviceDescription( libvlc_audio_output_device_t* d )
        {
            if ( d->psz_device != nullptr )
                m_device = d->psz_device;
            if ( d->psz_description != nullptr )
                m_description = d->psz_description;
        }

    private:
        std::string m_device;
        std::string m_description;
};

#if LIBVLC_VERSION_INT < LIBVLC_VERSION(4, 0, 0, 0)
///
/// \brief The TrackDescription class describes a track
///
class TrackDescription
{
public:
    ///
    /// \brief id The track id
    ///
    int id() const
    {
        return m_id;
    }

    ///
    /// \brief name The track name
    ///
    const std::string& name() const
    {
        return m_name;
    }

    explicit TrackDescription( libvlc_track_description_t* c )
        : m_id( c->i_id )
    {
        if ( c->psz_name != nullptr )
            m_name = c->psz_name;
    }

private:
    int m_id;
    std::string m_name;
};
#endif

#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(3, 0, 0, 0)
///
/// \brief The TitleDescription class describes a title
///
class TitleDescription
{
public:
    ///
    /// \brief duration The title duration in (ms)
    ///
    int64_t duration() const
    {
        return m_duration;
    }

    ///
    /// \brief name The title name
    ///
    const std::string& name() const
    {
        return m_name;
    }

    ///
    /// \brief name Is the title a menu?
    ///
    bool isMenu() const
    {
        return ( m_flags & libvlc_title_menu ) != 0;
    }

    bool isInteractive() const
    {
        return ( m_flags & libvlc_title_interactive ) != 0;
    }

    explicit TitleDescription( const libvlc_title_description_t* c )
        : m_duration( c->i_duration ), m_flags( c->i_flags )
    {
        if ( c->psz_name != nullptr )
            m_name = c->psz_name;
    }

private:
    int64_t m_duration;
    std::string m_name;
    int m_flags;
};

///
/// \brief The ChapterDescription class describes a chapter
///
class ChapterDescription
{
public:
    ///
    /// \brief timeoffset The chapter start time in (ms)
    ///
    int64_t starttime() const
    {
        return m_starttime;
    }

    ///
    /// \brief duration The chapter duration in (ms)
    ///
    int64_t duration() const
    {
        return m_duration;
    }

    ///
    /// \brief name The chapter name
    ///
    const std::string& name() const
    {
        return m_name;
    }

    explicit ChapterDescription( libvlc_chapter_description_t* c )
        : m_duration( c->i_duration ), m_starttime( c->i_time_offset )
    {
        if ( c->psz_name != nullptr )
            m_name = c->psz_name;
    }

private:
    int64_t m_duration, m_starttime;
    std::string m_name;
};
#endif

#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(3, 0, 0, 0)
///
/// \brief C++ Type wrapper for libvlc_media_slave_t
///
class MediaSlave
{
public:
    ///
    /// Type of a media slave: subtitle or audio.
    ///
    enum class Type
    {
        Subtitle = libvlc_media_slave_type_subtitle,
        Audio = libvlc_media_slave_type_audio
    };

    MediaSlave( libvlc_media_slave_t *m )
      : m_type( static_cast<Type>( m->i_type ) )
      , m_priority( m->i_priority )
      , m_uri( m->psz_uri )
    {
    }

public:
    Type type() const
    {
        return m_type;
    }

    unsigned priority() const
    {
        return m_priority;
    }

    const std::string& uri() const
    {
        return m_uri;
    }

private:
    Type m_type;
    unsigned int m_priority;
    std::string m_uri;
};


///
/// \brief C++ Type wrapper for libvlc_video_viewpoint_t
///
class VideoViewpoint : public libvlc_video_viewpoint_t
{
public:
    VideoViewpoint( float yaw, float pitch, float roll, float fieldOfView )
    {
        f_yaw = yaw;
        f_pitch = pitch;
        f_roll = roll;
        f_field_of_view = fieldOfView;
    }

public:
    float yaw() const
    {
        return f_yaw;
    }

    float pitch() const
    {
        return f_pitch;
    }

    float roll() const
    {
        return f_roll;
    }

    float field_of_view() const
    {
        return f_field_of_view;
    }
};

class RendererDiscovererDescription
{
public:
    explicit RendererDiscovererDescription( const libvlc_rd_description_t* d )
    {
        if (d->psz_name != nullptr)
            m_name = d->psz_name;
        if (d->psz_longname != nullptr)
            m_longName = d->psz_longname;
    }

    const std::string& name() const
    {
        return m_name;
    }

    const std::string& longName() const
    {
        return m_longName;
    }

private:
    std::string m_name;
    std::string m_longName;
};

#endif

} // namespace VLC
#endif
