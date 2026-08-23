/*****************************************************************************
 * Picture.hpp: Picture API
 *****************************************************************************
 * Copyright © 2018 libvlcpp authors & VideoLAN
 *
 * Authors: Hugo Beauzée-Luyssen <hugo@beauzee.fr>
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

#ifndef LIBVLC_CXX_PICTURE_HPP
#define LIBVLC_CXX_PICTURE_HPP

#include "common.hpp"

#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(4, 0, 0, 0)

namespace VLC
{

class Picture : public Internal<libvlc_picture_t>
{
public:
    enum class Type : uint8_t
    {
        Argb = libvlc_picture_Argb,
        Jpg = libvlc_picture_Jpg,
        Png = libvlc_picture_Png,
    };

    Picture() = default;

    explicit Picture( Internal::InternalPtr ptr )
        : Internal( ptr, libvlc_picture_release )
    {
        libvlc_picture_retain( ptr );
    }

    /**
     * Saves this picture to a file. The image format is the same as the one
     * returned by \link Picture::type() \endlink
     *
     * \param path The path to the generated file
     * \return true in case of success, false otherwise
     */
    bool save( const std::string& path ) const
    {
        return libvlc_picture_save( *this, path.c_str() ) == 0;
    }

    /**
     * Returns the image internal buffer, including potential padding.
     * The picture instance owns the returned buffer, which must not be modified
     * nor freed.
     *
     * \param size A pointer to a size_t that will hold the size of the buffer [out] [required]
     * \return A pointer to the internal buffer.
     */
    const uint8_t* buffer( size_t* size ) const
    {
        return libvlc_picture_get_buffer( *this, size );
    }

    /**
     * Returns the picture type
     *
     * \see Picture::Type
     */
    Type type() const
    {
        return static_cast<Type>( libvlc_picture_type( *this ) );
    }

    /**
     * Returns the image stride, ie. the number of bytes per line.
     * This can only be called on images of type Picture::Type::Argb
     */
    uint32_t stride() const
    {
        return libvlc_picture_get_stride( *this );
    }

    /**
     * Returns the width of the image in pixels
     */
    uint32_t width() const
    {
        return libvlc_picture_get_width( *this );
    }

    /**
     * Returns the height of the image in pixels
     */
    uint32_t height() const
    {
        return libvlc_picture_get_height( *this );
    }

    /**
     * Returns the time at which this picture was generated, in milliseconds
     */
    libvlc_time_t time() const
    {
        return libvlc_picture_get_time( *this );
    }
};

}

#endif

#endif // LIBVLC_CXX_PICTURE_HPP
