module Dropbox
  module API
    class Client
      
      def ls_p(path_to_list = '')
        ls(path_to_list)
      rescue Dropbox::API::Error::NotFound
        mkdir(path_to_list)
        []
      end
      
      def make_metas
        path = "images/metas"
        metas = ls_p(path).map {|f|
          name = f.path.split('/').pop
          name.split('.')[0] + '.json'
        }
        ls('images').each do |f|
          next if f.is_dir
          name = f.path.split('/').pop
          name = name.split('.')[0] + '.json'
          next if metas.include?(name)
          upload "#{path}/#{name}", "{}"
        end  
      end

      def get_metas
        dict = {}
        ls_p("images/metas").each { |f|
          name = f.path.split('/').pop
          name = name.split('.')[0] + '.json'
          dict["images/metas/#{name}"] = f
        }
        dict
      end
      
      def make_thumbs(size)
        thumbs_path = "images/thumbs/#{size}"
        thumbs = ls_p(thumbs_path).map {|f| f.path }
        ls('images').each do |f|
          next unless f.thumb_exists
          next if thumbs.include?(f.path)
          upload "#{thumbs_path}/#{f.path.split('/').pop}", f.thumbnail(:size => size)
        end  
      end

      def get_thumbs(size)
        dict = {}
        ls_p("images/thumbs/#{size}").each { |t| dict[t.path] = t}
        dict
      end
      
      def get_images(opts)
        files = opts[:path] ? ls(opts[:path]) : ls
        files = attach_thumbs(files, opts)
        files = attach_metas(files, opts)
        files
      end
            
      def attach_metas(files, opts)
        make_metas if opts[:make]
        metas = get_metas

        files.each do |f|
          name = f.path.split('/').pop
          name = name.split('.')[0] + '.json'
          meta = metas["images/metas/#{name}"]
          next unless meta
          f['meta'] = JSON.parse(download(meta.path)) rescue {}
        end

        files
      end
      
      def attach_thumbs(files, opts)
        opts[:size] ||= :medium
        make_thumbs(opts[:size]) if opts[:make]
        thumbs = get_thumbs(opts[:size])
        
        files.each do |f|
          next unless f.thumb_exists
          f['thumbs'] = {} unless f['thumbs']
          thumb = thumbs["images/thumbs/#{opts[:size]}/#{f.path.split('/').pop}"]
          next unless thumb
          f['thumbs']['m'] = thumb.direct_url['url']
        end

        files
      end
      
    end
  end
end