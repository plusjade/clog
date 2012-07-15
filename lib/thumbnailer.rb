module Dropbox
  module API
    class Client
      
      def ls_p(path_to_list = '')
        ls(path_to_list)
      rescue Dropbox::API::Error::NotFound
        mkdir(path_to_list)
        []
      end
      
      def make_thumbs(size)
        thumbs_path = "thumbs/#{size}"
        thumbs = @client.ls_p(thumbs_path).map {|f| f.path }
        ls.each do |f|
          next unless f.thumb_exists
          next if thumbs.include?(f.path)
          @client.upload "#{thumbs_path}/#{f.path}", f.thumbnail(:size => size)
        end  
      end

      def get_thumbs(size)
        dict = {}
        ls_p("thumbs/#{size}").each { |t| dict[t.path] = t}
        dict
      end

      def get_files_with_thumbs(opts)
        opts[:size] ||= :medium
        make_thumbs(opts[:size]) if opts[:make]
        thumbs = get_thumbs(opts[:size])
        files = opts[:path] ? ls(opts[:path]) : ls

        files.each do |f|
          next unless f.thumb_exists
          f['thumbs'] = {} unless f['thumbs']
          thumb = thumbs["thumbs/#{opts[:size]}/#{f.path.split('/').pop}"]
          next unless thumb
          f['thumbs']['m'] = thumb.direct_url['url']
        end

        files
      end
      
    end
  end
end