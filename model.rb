module Model

    #Returnerar en instans av databasen
    def connect_to_db()
        path = "db/snabbspringning.db"
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end

    #Är ett visst namn accepterat?
    def name_accepted?(name)
        if name == "" || name =~ /\A\s*\Z/
            return false
        end
        return true
    end

    def exists_username?(username)
        return get_user_with_username(username) != nil
    end

    def exists_category_name?(name)
        #Kolla att det inte redan finns en kategori med detta namn
        db = connect_to_db()
        category = db.execute("SELECT * FROM Categories WHERE name = ?", name).first
        return category != nil
    end

    def password_accepted?(password)
        #Se till att det finns minst 8 unika tecken
        unique_length = password.split("").uniq.length
        return unique_length >= 8
    end

    #Kollar om en viss tid är accepterad eller inte
    #Tar en array med timmar, minuter, sekunder & hundradelar som input
    def check_time_input_accepted(time_input, category_id)
        #Kontrollerar om någon tid är negativ
        time_input.each do |time|
            if time < 0
                display_information("Din tid kan inte vara negativ", "Tillbaka", "/times/#{category_id}/new")
                return
            end
        end
        hours, minutes, seconds, fractions = time_input

        #Kontrollerar att tiden inte är större än 2000h
        if hours > 2000
            display_information("Din tid kan inte överstiga 2000 timmar.", "Tillbaka", "/times/#{category_id}/new")
            return
        end

        #Kontrollerar att inga värden (förutom timmar) överstiger 59
        if minutes >= 60 || seconds >= 60 || fractions >= 100
            display_information("Fel, du måste skriva på rätt format, där minuter/sekunder är mindre än 60 och hundradelar är mindre än 100", "Tillbaka", "/times/#{category_id}/new")
            return
        end
    end

    #Formaterar en sträng som visar en tid på formatet hh:mm:ss:ff
    def time_to_string(h, m, s, f)
        return "#{h}:#{m / 10}#{m % 10}:#{s / 10}#{s % 10}.#{f / 10}#{f % 10}"
    end

    #Analyserar en tids-sträng och konverterar den till en mer jämförbar kvantitet
    def parsetime(time)
        l = time.split(".")
        h, m, s = l[0].split(":").map(&:to_i)
        f = l[1].to_i
        return f + s * 100 + m * 6000 + h * 360000
    end

    #Sorterar en vektor av instanser av time-entiteten med själva tiden som booleansk jämförare
    def sort_times(times)
        times.sort! do |a, b|
            a_time, b_time = parsetime(a["time"]), parsetime(b["time"])
            if a_time == b_time
                date_a, date_b = DateTime.parse(a["date"]), DateTime.parse(b["date"])
                seconds_a, seconds_b = date_a.strftime('%s'), date_b.strftime('%s')
                seconds_a <=> seconds_b
            else #Om tiderna är identiska, prioritera den som skickades in först
                a_time <=> b_time
            end
        end
    end

    #DATABASFUNKTIONER

    #Hitta och returnera användarnamnet för användaren med ett visst id
    def get_username_with_id(id)
        db = connect_to_db()
        user = db.execute('SELECT username From Users WHERE id = ?', id).first
        return user
    end

    def get_user_id_with_id(id)
        db = connect_to_db()
        user_id = db.execute('SELECT id From Users WHERE id = ?', id).first
        return user_id
    end

    def get_time_user_id(time_id)
        db = connect_to_db()
        user_id = db.execute('SELECT user_id From Times WHERE id = ?', time_id).first
        return user_id
    end

    #Hämta alla kategorier som finns
    def get_all_categories()
        db = connect_to_db()
        categories = db.execute('SELECT * FROM Categories')
        return categories
    end

    #Hämta alla tider som finns sparade för en viss kategori
    def get_all_times_from_category(category_id)
        db = connect_to_db()
        times = db.execute('SELECT * FROM Times WHERE category_id = ?', category_id)
        return times
    end

    #Hämta en rad från entiteten kategori från databasen
    def get_category(category_id)
        db = connect_to_db()
        cat = db.execute('SELECT * FROM Categories WHERE id = ?', category_id).first
        return cat
    end

    def get_rel(user_id, category_id)
        db = connect_to_db()
        like = db.execute("SELECT * FROM users_categories_rel WHERE user_id = ? AND category_id = ?", user_id, category_id).first
        return like
    end

    def get_all_users_liking_category(category_id)
        db = connect_to_db()
        users_liking = db.execute("SELECT * FROM users_categories_rel INNER JOIN Users ON users_categories_rel.user_id = Users.id WHERE category_id = ?", category_id)
        return users_liking
    end

    def update_category_name(new_name, category_id)
        db = connect_to_db()
        db.execute('UPDATE Categories SET name = ? WHERE id = ?', new_name, category_id)
    end

    def delete_category(category_id)
        db = connect_to_db()
        db.execute("DELETE FROM Categories WHERE id=?", category_id)
        db.execute("DELETE FROM Times WHERE category_id = ?", category_id)
    end

    def insert_category(name, user_id)
        db = connect_to_db()
        db.execute('INSERT INTO Categories (name, user_id) VALUES (?, ?)', name, user_id)
    end

    def get_time(time_id)
        db = connect_to_db()
        time = db.execute('SELECT * FROM Times WHERE id = ?', time_id).first
        return time
    end

    def insert_time(time_string, date, category_id, user_id)
        db = connect_to_db()
        db.execute('INSERT INTO Times (time, date, category_id, user_id) VALUES (?, ?, ?, ?)', time_string, date, category_id, user_id)
    end

    def delete_time(time_id)
        db = connect_to_db()
        db.execute("DELETE FROM Times WHERE id = ?", time_id)
    end

    def get_user_with_username(username)
        db = connect_to_db()
        user = db.execute("SELECT * FROM Users WHERE username=?", username).first
        return user
    end

    def get_user_id_with_username(username)
        db = connect_to_db()
        user_id = db.execute("SELECT id FROM Users WHERE username=?", username).first
        return user_id
    end

    def get_user(id)
        db = connect_to_db()
        user = db.execute("SELECT * FROM Users WHERE id = ?", id).first
        return user
    end

    def insert_user(username, password_digest)
        db = connect_to_db()
        db.execute('INSERT INTO Users (username, pw_digest) VALUES (?, ?)', username, password_digest)
    end

    def get_all_categories_by_user_id(user_id)
        db = connect_to_db()
        categories = db.execute("SELECT * FROM Categories WHERE user_id = ?", user_id)
        return categories
    end

    def get_all_times_by_user_id(user_id)
        db = connect_to_db()
        times = db.execute("SELECT * FROM Times WHERE user_id = ?", user_id)
        return times
    end

    def get_category_name(id)
        db = connect_to_db()
        name = db.execute("SELECT name FROM Categories WHERE id = ?", id).first
        return name
    end

    def get_all_categories_liked_by_user(user_id)
        db = connect_to_db()
        categories_liking = db.execute("SELECT * FROM users_categories_rel INNER JOIN Categories ON users_categories_rel.category_id = Categories.id WHERE users_categories_rel.user_id = ?", user_id)
        return categories_liking
    end

    def update_password(password_digest, id)
        db = connect_to_db()
        db.execute("UPDATE Users SET pw_digest = ? WHERE id = ?", password_digest, id)
    end

    def insert_rel(user_id, category_id)
        db = connect_to_db()
        db.execute("INSERT INTO users_categories_rel (user_id, category_id) VALUES (?, ?)", user_id, category_id)
    end

    def delete_rel(user_id, category_id)
        db = connect_to_db()
        db.execute("DELETE FROM users_categories_rel WHERE user_id = ? AND category_id = ?", user_id, category_id)
    end

end