# pg_dump 17.6+ writes a random \restrict / \unrestrict token pair into every
# dump, so db/structure.sql changed on each migration even with no schema
# change. The token only guards interactive psql restores; strip it so the
# file stays stable in git.
Rake::Task["db:schema:dump"].enhance do
  path = Rails.root.join("db/structure.sql")
  next unless path.exist?

  content = path.read
  cleaned = content.gsub(/^\\(?:un)?restrict \S+\n/, "")
  path.write(cleaned) unless cleaned == content
end
