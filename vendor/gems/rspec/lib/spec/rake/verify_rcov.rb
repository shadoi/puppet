module RCov
  # A task that can verify that the RCov coverage doesn't
  # drop below a certain threshold. It should be run after
  # running Spec::Rake::SpecTask.
  class VerifyTask < Rake::TaskLib
    # Name of the task. Defaults to :verify_rcov
    attr_accessor :name
    
    # Path to the index.html file generated by RCov, which
    # is the file containing the total coverage.
    # Defaults to 'coverage/index.html'
    attr_accessor :index_html
    
    # Whether or not to output details. Defaults to true.
    attr_accessor :verbose
    
    # The threshold value (in percent) for coverage. If the 
    # actual coverage is not equal to this value, the task will raise an 
    # exception. 
    attr_accessor :threshold
    
    # Require the threshold value be met exactly.  This is the default.
    attr_accessor :require_exact_threshold
    
    def initialize(name=:verify_rcov)
      @name = name
      @index_html = 'coverage/index.html'
      @verbose = true
      @require_exact_threshold = true
      yield self if block_given?
      raise "Threshold must be set" if @threshold.nil?
      define
    end
    
    def define
      desc "Verify that rcov coverage is at least #{threshold}%"
      task @name do
        total_coverage = nil

        File.open(index_html).each_line do |line|
          if line =~ /<tt.*>(\d+\.\d+)%<\/tt>&nbsp;<\/td>/
            total_coverage = eval($1)
            break
          end
        end
        puts "Coverage: #{total_coverage}% (threshold: #{threshold}%)" if verbose
        raise "Coverage must be at least #{threshold}% but was #{total_coverage}%" if total_coverage < threshold
        raise "Coverage has increased above the threshold of #{threshold}% to #{total_coverage}%. You should update your threshold value." if (total_coverage > threshold) and require_exact_threshold
      end
    end
  end
end