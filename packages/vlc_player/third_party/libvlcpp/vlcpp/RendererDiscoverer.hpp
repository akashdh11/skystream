/*****************************************************************************
 * RendererDiscovery.hpp: Media Discoverer API
 *****************************************************************************
 * Copyright © 2015-2018 libvlcpp authors & VideoLAN
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

#ifndef LIBVLC_CXX_RENDERERDISCOVERER_HPP
#define LIBVLC_CXX_RENDERERDISCOVERER_HPP

#include "common.hpp"

#if LIBVLC_VERSION_INT >= LIBVLC_VERSION(3, 0, 0, 0)

namespace VLC
{

class RendererDiscovererEventManager;

class RendererDiscoverer : public Internal<libvlc_renderer_discoverer_t>
{
public:
    class Item : public Internal<libvlc_renderer_item_t>
    {
    private:
        Item( InternalPtr item ) : Internal( item, libvlc_renderer_item_release )
        {
            libvlc_renderer_item_hold( *this );
        }

    public:
        std::string name() const
        {
            return libvlc_renderer_item_name( *this );
        }

        std::string type() const
        {
            return libvlc_renderer_item_type( *this );
        }

        std::string iconUri() const
        {
            return libvlc_renderer_item_icon_uri( *this );
        }

        bool canRenderVideo() const
        {
            return ( libvlc_renderer_item_flags( *this ) &
                     LIBVLC_RENDERER_CAN_VIDEO ) != 0;
        }

        bool canRenderAudio() const
        {
            return ( libvlc_renderer_item_flags( *this ) &
                     LIBVLC_RENDERER_CAN_AUDIO ) != 0;
        }

        friend RendererDiscovererEventManager;
    };

    RendererDiscoverer( const Instance& instance, const std::string& name )
        : Internal( libvlc_renderer_discoverer_new( getInternalPtr<libvlc_instance_t>( instance ),
                                                    name.c_str() ), libvlc_renderer_discoverer_release )
    {
    }

    bool start()
    {
        return libvlc_renderer_discoverer_start( *this ) == 0;
    }

    void stop()
    {
        libvlc_renderer_discoverer_stop( *this );
    }

    RendererDiscovererEventManager& eventManager()
    {
        if ( m_eventManager == nullptr )
        {
            libvlc_event_manager_t* obj = libvlc_renderer_discoverer_event_manager( *this );
            m_eventManager = std::make_shared<RendererDiscovererEventManager>( obj, *this );
        }
        return *m_eventManager;
    }

private:
    std::shared_ptr<RendererDiscovererEventManager> m_eventManager;
};

}

#endif

#endif // LIBVLC_CXX_RENDERERDISCOVERER_HPP
