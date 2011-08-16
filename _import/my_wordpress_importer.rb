require 'rubygems'
require 'sequel'
require 'fileutils'
require 'pp'
require 'jekyll'

module Jekyll
	module MyWordPressImporter

		def self.process(dbname, user, pass, host = 'localhost')

			puts "Remove old archive directory? [Yn]"
			remove = STDIN.gets.chomp

			if remove != "n"
				FileUtils.remove_dir(Jekyll::MyWordPressImporter::archive_path, true)
			end
	
			puts "Starting Wordpress Migration"
      
			db = Sequel.mysql(dbname, :user => user, :password => pass, :host => host)
			puts "Connecting to #{dbname} on #{host}"
      
			FileUtils.makedirs Jekyll::MyWordPressImporter::archive_path
			puts "Creating #{Jekyll::MyWordPressImporter::archive_path} directories"
      
			total_posts = db["select ID, post_author, post_date, post_date_gmt, post_content, post_title, post_status from wp_posts"].count
			puts "Found #{total_posts} entries"
			puts "Starting to parse entries"

			post_count = 1
      
			db["SELECT ID, post_name, guid, post_date, post_date_gmt, post_content, post_title, post_category, post_status FROM wp_posts ORDER BY ID"].each do |post|
        
	        puts "--------------------------------------------------------------------------------"
	        puts "#{post_count} of #{total_posts} - #{post[:post_title]}"

	        slug = post[:post_title].to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+$/, '').gsub(/^-+$/, '')
        
	        date = post[:post_date]
	        puts "\t- status is #{post[:post_status]}"
	        puts "\t- date is #{post[:post_date]}"
        
	        file_name = "%02d-%02d-%02d-%s.html" % [date.year, date.month, date.day, slug]
	        puts "\t- will be called #{file_name}"
        
			categories = []
			# categories = [{
			# 	"id"		=>	34,
			# 	"title"	=>	"Veryraw",
			# 	"slug"	=>	"veryraw"
			# }]

			db["SELECT wp_categories.cat_ID, wp_categories.cat_name, wp_categories.category_nicename FROM wp_categories, wp_posts, wp_post2cat WHERE wp_categories.cat_ID=wp_post2cat.category_id AND wp_post2cat.post_id=wp_posts.ID AND wp_posts.ID=#{post[:ID]}"].each do |category|
				categories.push({
					"id"	=>	category[:cat_ID],
					"title"	=>	category[:cat_name].to_s.capitalize,
					"slug"	=>	category[:category_nicename].to_s
				})
			end
			puts "\t- has #{categories.size} categories"

			comments = []
			db[Jekyll::MyWordPressImporter.comments_by_post_query(post[:ID])].each do |comment|
				comments.push({
					"id"			=>	comment[:comment_ID],
					"author"		=>	comment[:comment_author].to_s,
					"author_email"	=>	comment[:comment_author_email].to_s,
					"author_url"	=>	comment[:comment_author_url].to_s,
					"date"			=>	comment[:comment_date],
					"date_gmt"		=>	comment[:comment_date_gmt],
					"content"		=>	comment[:comment_content].to_s
				})
			end

			comment_count = comments.size
			comments = nil if comments.empty?
			puts "\t- has #{comment_count} comments"
        
			front_matter = {
				'layout'	=>	'archive',
				'published'	=>	false,

				'title'		=>	post[:post_title].to_s,
				'slug'		=>	slug,
				'category'	=>	'veryraw',

				'wordpress'	=>	{
					'id'			=>	post[:ID],
					'status'		=>	post[:post_status].to_s,
					'date'			=>	post[:post_date],
					'date_gmt'		=>	post[:post_date_gmt],
					'guid'			=>	post[:guid].to_s,
					'categories'	=>	categories
				},

				'comments'	=>	{
					'show'		=>	false,
					'count'		=>	comment_count,
					'list'		=>	comments
				}

			}.delete_if { |k,v| v.nil? || v == ''}.to_yaml

			Jekyll::MyWordPressImporter::append_entry(file_name, front_matter)
			Jekyll::MyWordPressImporter::append_entry(file_name, "---")
			Jekyll::MyWordPressImporter::append_entry(file_name, post[:post_content].to_s)
                
			post_count += 1
			end

		end 
		
		def self.append_entry(file, content)
			File.open("#{Jekyll::MyWordPressImporter::archive_path}/#{file}", "a") do |f|
				f.puts content
				f.puts "\r"
			end
		end
		
		def self.comments_by_post_query(post_id)
			return <<-QUERY.gsub(/\t/, '')
				SELECT wp_comments.comment_ID, wp_comments.comment_author, wp_comments.comment_author_email, 
					wp_comments.comment_author_url, wp_comments.comment_date, wp_comments.comment_date_gmt, 
					wp_comments.comment_content, wp_comments.comment_agent, wp_comments.comment_type, 
					wp_comments.comment_parent FROM wp_comments, wp_posts 
				WHERE wp_comments.comment_post_ID=wp_posts.ID AND wp_posts.ID=#{post_id}
			QUERY
		end
		
		def self.posts_query
			return <<-QUERY.gsub(/\t/, '')
				SELECT ID, post_author, post_date, post_date_gmt, post_content, post_title, post_status 
				FROM wp_posts
			QUERY
		end
		
		def self.archive_path
			File.expand_path(File.join(File.dirname(__FILE__), *%w(.. _posts veryraw)))
		end
    
	end # module MyWordPressImporter
end # module Jekyll
