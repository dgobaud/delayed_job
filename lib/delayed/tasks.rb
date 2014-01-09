namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear => :environment do
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment_options do
    if @worker_options[:num_processes] == 1
      Delayed::Worker.new(@worker_options).start
    else
      def fork_delayed(worker_index)
        puts "starting worker #{worker_index}"

        fork do
          Delayed::Worker.after_fork
          worker = Delayed::Worker.new(@worker_options)
          worker.name_prefix = "delayed_job.#{worker_index} "
          worker.start
        end
      end

      Delayed::Worker.before_fork
      @worker_options[:num_processes].times do |worker_index|
        fork_delayed(worker_index)
      end

      worker_index = @worker_options[:num_processes]

      while true do
        Process.wait()

        fork_delayed(worker_index)
        worker_index = worker_index + 1
      end
    end
  end

  desc "Start a delayed_job worker and exit when all available jobs are complete."
  task :workoff => :environment_options do
    Delayed::Worker.new(@worker_options.merge({:exit_on_complete => true})).start
  end

  task :environment_options => :environment do
    @worker_options = {
      :min_priority => ENV['MIN_PRIORITY'],
      :max_priority => ENV['MAX_PRIORITY'],
      :queues => (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
      :quiet => false
    }
  end

  desc "Exit with error status if any jobs older than max_age seconds haven't been attempted yet."
  task :check, [:max_age] => :environment do |_, args|
    args.with_defaults(:max_age => 300)

    unprocessed_jobs = Delayed::Job.where('attempts = 0 AND created_at < ?', Time.now - args[:max_age].to_i).count

    if unprocessed_jobs > 0
      fail "#{unprocessed_jobs} jobs older than #{args[:max_age]} seconds have not been processed yet"
    end

  end

end
