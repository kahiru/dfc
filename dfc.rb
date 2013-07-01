#!/usr/bin/ruby

require 'optparse'
require 'net/http'
require 'json'
require_relative 'ansicolor'

class Thread4c
  attr_reader :threadnum
  def initialize(board,threadnum)
    @boardname=board
    @threadnum=threadnum
    @posts=[]
    self.load_json(@boardname,@threadnum)
  end

  def load_json(board, threadnum)
    url='http://api.4chan.org/'+board+'/res/'+threadnum+'.json'
    resp=Net::HTTP.get_response(URI.parse(url))
    posts=JSON.parse(resp.body)['posts']
    posts.each do |post|
      postnum=post['no']
      if post.has_key?('tim')
        ofilename=post['filename'].to_s+post['ext']
        filename=post['tim'].to_s+post['ext']
        x=post['w']
        y=post['h']
        self.add_post(postnum,x,y,filename,ofilename)
      else
        self.add_post(postnum)
      end
    end
  end

  def add_post(postnum,x=-1,y=-1,imgname=nil,ofilename=nil)
    temp=Post.new(@boardname,postnum,x,y,imgname,ofilename)
    @posts << temp
  end

  def download_images()
    @posts.each { |post| post.download_image if post.has_image? }
  end

  def delete_images()
    @posts.each { |post| post.delete_image if post.has_image? }
  end
end

class Post
  def initialize(board,postnum,x=-1,y=-1,imgname=nil,ofilename=nil)
    @board=board
    @postnum=postnum
    @imgx=x
    @imgy=y
    @imgname=imgname
    @oimgname=ofilename
  end

  def has_image?()
    if @imgname==nil
      $astats[:ni]+=1
      print Colors::RED if $options[:color]
      puts "[ NI ]\t#{@postnum}" if $options[:verbose]
      print Colors::RESET if $options[:color]
      return false
    else
      if (@imgx.to_i>=$options[:x].to_i) && (@imgy.to_i>=$options[:y].to_i)
        return true
      else
        print Colors::YELLOW if $options[:color]
        $astats[:sl]+=1
        if $options[:verbose]
          puts "[ SL ]\t#{@imgname}\t#{@imgx}x#{@imgy}\t#{@oimgname}"
        else
          puts "[ SL ]\t#{@imgname}" unless $options[:quiet]
        end
        print Colors::RESET if $options[:color]
        return false
      end
    end
  end

  def delete_image()
    if File.exists?(@imgname)
      File.delete(@imgname)
      print Colors::GREEN if $options[:color]
      puts "[ DL ]\t#{@postnum}" unless $options[:quiet]
      print Colors::RESET if $options[:color]
      $astats[:dl]+=1
    else
      print Colors::RED if $options[:color]
      puts "[ NI ]\t#{@postnum}" if $options[:verbose]
      print Colors::RESET if $options[:color]
    end
  end

  def download_image()
    if not File.exist?(@imgname)
      http=Net::HTTP.start('images.4chan.org')
      resp=http.get('/'+@board+'/src/'+@imgname)
      of=open(@imgname,'wb')
      of.write(resp.body)
      $astats[:dl]+=1
      print Colors::GREEN if $options[:color]
      if $options[:verbose]
        puts "[ DL ]\t#{@imgname}\t#{@imgx}x#{@imgy}\t#{@oimgname}"
      else
        if not $options[:quiet]
          puts "[ DL ]\t#{@imgname}"
        end
      end
      print Colors::RESET if $options[:color]
    else
      $astats[:sp]+=1
      print Colors::CYAN if $options[:color]
      if $options[:verbose]
        puts "[ SP ]\t#{@imgname}\t#{@imgx}x#{@imgy}\t#{@oimgname}"
      else
        if not $options[:quiet]
          puts "[ SP ]\t#{@imgname}"
        end
      end
      print Colors::RESET if $options[:color]
    end
  end
end

$options = {}
optparse = OptionParser.new { |opts|
  opts.banner = "Usage: dfc.rb [$options] thread#1 thread#2..."
  $options[:verbose]=false
  $options[:quiet]=false
  $options[:x]=-1
  $options[:y]=-1
  $options[:color]=false
  $options[:sepfol]=false
  $options[:folder]='.'
  opts.on('-v','--verbose', 'Output more information') { $options[:verbose]=true; $options[:quiet]=false }
  opts.on('-q','--quiet','Print no output') { $options[:quiet]=true; $options[:verbose]=false }
  opts.on('-x','--x x', 'Set minimal x resolution') { |x| $options[:x]=x }
  opts.on('-y','--y y', 'Set minimal y resolution') { |y| $options[:y]=y }
  opts.on('-r', '--res XxY', 'Set minimal XxY resolution') { |res| x,y=res.split('x'); $options[:x]=x; $options[:y]=y }
  opts.on('-c','--color', 'Colorize output') { $options[:color]=true }
  opts.on('-f','--folder FOLDER', 'Save images to FOLDER') { |folder| $options[:folder]=folder.end_with?('/') ? folder.sub(/\/$/,'') : $options[:folder]=folder }
  opts.on('-b','--board BOARD', 'Specify a board, take thread numbers from args') { |board| $options[:board]=board }
  opts.on('-i','--input', 'Take links/threads from STDIN') { $options[:input]=true }
  opts.on('-s','--separate-folders','Save each thread to its own folder') { $options[:sepfol]=true }
  opts.on('-d','--delete','Removes images from folder') { $options[:delete]=true }
  opts.on('-h', '--help', 'Display this screen') { puts opts; exit }
}

optparse.parse!

if $options[:folder]!=nil
  if not Dir.exists?($options[:folder])
    if $options[:delete]
      puts "Folder does not exist. Nothing to remove."
    end
    Dir.mkdir($options[:folder])
  end
  puts "Folder #{$options[:folder]}" unless $options[:quiet]
  Dir.chdir($options[:folder])
end

threads=[]
ARGV.each do |arg|
  if  $options[:board]==nil
    arg.match(/\.org\/(.*?)\/res\/(\d+)/)
    threads.push(Thread4c.new($1,$2))
  else
    threads.push(Thread4c.new($options[:board],arg))
  end
end
if $options[:input]
  temp=gets()
  temp=temp.split(" ")
  temp.each do |thread|
    if  $options[:board]==nil
      thread.match(/\.org\/(.*?)\/res\/(\d+)/)
      threads.push(Thread4c.new($1,$2))
    else
      threads.push(Thread4c.new($options[:board],thread))
    end
  end
end

$astats={}
$astats[:dl]=0
$astats[:sp]=0
$astats[:sl]=0
$astats[:ni]=0

threads.each { |thread|
  if $options[:sepfol]
    unless Dir.exists?(thread.threadnum)
      Dir.mkdir(thread.threadnum)
    end
    puts
    puts "Folder #{$options[:folder]}/#{thread.threadnum}/" unless $options[:quiet]
    Dir.chdir(thread.threadnum)
  end
  if $options[:delete]
    thread.delete_images()
  else
    thread.download_images()
  end
  Dir.chdir('..') if $options[:sepfol]
}
begin
  puts
  print Colors::GREEN if $options[:color]
  puts "[ DL ]\t#{$astats[:dl]}"
  print Colors::CYAN if $options[:color]
  puts "[ SP ]\t#{$astats[:sp]}"
  print Colors::YELLOW if $options[:color]
  puts "[ SL ]\t#{$astats[:sl]}"
  print Colors::RED if $options[:color]
  puts "[ NI ]\t#{$astats[:ni]}" if $options[:verbose]
  print Colors::RESET if $options[:color]
end unless $options[:quiet]
