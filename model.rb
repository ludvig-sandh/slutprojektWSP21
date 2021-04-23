# Model-delen av applikationen. Applikationen följer MVC-standarden
# 
module Model

    # Returnerar en instans av databasen
    #
    # @return [SQLite::Database]
    def connect_to_db()
        path = "db/snabbspringning.db"
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end

    # Tar reda på om ett visst namn är accepterat eller inte
    # 
    # @param [String] name namnet som vi ska kolla på
    # @return [Boolean]
    def name_accepted?(name)
        if name == "" || name =~ /\A\s*\Z/
            return false
        end
        return true
    end

    # Tar reda på om ett visst användarnamn finns sparat i databasen redan eller inte
    # 
    # @param [String] username användarnamnet som vi ska kolla på
    # @see Model#get_user_with_username
    # @return [Hash]
    def exists_username?(username)
        return get_user_with_username(username) != nil
    end

    # Tar reda på om ett visst kategorinamn finns sparat i databasen redan eller inte
    # 
    # @param [String] name kategorinamnet som vi ska kolla på
    # @see Model#connect_to_db
    # @return [Boolean]
    def exists_category_name?(name)
        #Kolla att det inte redan finns en kategori med detta namn
        db = connect_to_db()
        category = db.execute("SELECT * FROM Categories WHERE name = ?", name).first
        return category != nil
    end

    # Tar reda på om ett visst lösenordet är accepterat eller inte. (Måste vara minst 8 distinkta tecken)
    # 
    # @param [String] password lösenordet som vi ska kolla på
    # @return [Boolean]
    def password_accepted?(password)
        #Se till att det finns minst 8 unika tecken
        unique_length = password.split("").uniq.length
        return unique_length >= 8
    end

    # Kollar om en viss tid är accepterad eller inte
    #
    # @param [Array] time_input innehåller heltal som beskriver heltalen timmar, minuter, sekunder & hundradelar från formuläret
    # @param [Integer] category_id kategorins id som vi kollar på
    # @see display_information
    # @returns [nil]
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

    # Formaterar en sträng som visar en tid på formatet hh:mm:ss:ff
    # 
    # @param [Integer] h antal timmar
    # @param [Integer] m antal minuter
    # @param [Integer] s antal sekunder
    # @param [Integer] f antal hundradelar
    # @return [String] den formatterade tidssträngen
    def time_to_string(h, m, s, f)
        return "#{h}:#{m / 10}#{m % 10}:#{s / 10}#{s % 10}.#{f / 10}#{f % 10}"
    end

    # Analyserar en tids-sträng och konverterar den till en mer jämförbar kvantitet
    # 
    # @param [String] time tidssträngen som vi ska analysera
    # @return [Integer] totalt antal hundradelar som tiden består av
    def parsetime(time)
        l = time.split(".")
        h, m, s = l[0].split(":").map(&:to_i)
        f = l[1].to_i
        return f + s * 100 + m * 6000 + h * 360000
    end

    # Sorterar en vektor av instanser av time-entiteten med själva tiden som booleansk jämförare
    # 
    # @param [Array] times en array med hashes. Varje hash beskriver en instans av entiteten Times
    # @return [Array] array med samma hashes fast sorterade efter snabbast tid
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

    # Hitta och returnera användarnamnet för användaren med ett visst id
    # 
    # @param [Integer] id id på användaren vi ska hitta
    # @see Model#connect_to_db
    # @return [Hash] hashen som innehåller information om användarnamnet
    def get_username_with_id(id)
        db = connect_to_db()
        user = db.execute('SELECT username From Users WHERE id = ?', id).first
        return user
    end

    # Hitta och returnera användar-id:t för användaren som skapat en viss tid
    # 
    # @param [Integer] time_id id:t på tiden som vi kollar på
    # @see Model#connect_to_db
    # @return [Hash] hashen som innehåller information om användar_id
    def get_time_user_id(time_id)
        db = connect_to_db()
        user_id = db.execute('SELECT user_id From Times WHERE id = ?', time_id).first
        return user_id
    end

    # Hämtar alla kategorier som finns
    # 
    # @see Model#connect_to_db
    # @return [Array] en array med alla kategorier (som beskrivs som hashes)
    def get_all_categories()
        db = connect_to_db()
        categories = db.execute('SELECT * FROM Categories')
        return categories
    end

    # Hämta alla tider som finns sparade för en viss kategori
    # 
    # @param [Integer] category_id id:t på kategorin som vi kollar på
    # @see Model#connect_to_db
    # @return [Array] en array med alla tider för kategorin (som beskrivs med hashes)
    def get_all_times_from_category(category_id)
        db = connect_to_db()
        times = db.execute('SELECT * FROM Times WHERE category_id = ?', category_id)
        return times
    end

    # Hämta en rad från entiteten Categories från databasen, dvs kategorin med ett visst kategori-id
    # 
    # @param [Integer] category_id id:t på kategorin som vi kollar på
    # @see Model#connect_to_db
    # @return [Hash] kategorin i form av en hash
    def get_category(category_id)
        db = connect_to_db()
        cat = db.execute('SELECT * FROM Categories WHERE id = ?', category_id).first
        return cat
    end

    # Hämta en relation mellan Users och Categories om den finns
    # 
    # @param [Integer] user_id id:t på användaren som vi kollar på
    # @param [Integer] category_id id:t på kategorin som vi kollar på
    # @see Model#connect_to_db
    # @return [Hash] relationen i form av en hash
    def get_rel(user_id, category_id)
        db = connect_to_db()
        like = db.execute("SELECT * FROM users_categories_rel WHERE user_id = ? AND category_id = ?", user_id, category_id).first
        return like
    end

    # Hämta alla användare som gillar en viss kategori
    # 
    # @param [Integer] category_id id:t på kategorin som vi kollar på
    # @see Model#connect_to_db
    # @return [Array] en array med alla användare (som beskrivs med hashes)
    def get_all_users_liking_category(category_id)
        db = connect_to_db()
        users_liking = db.execute("SELECT * FROM users_categories_rel INNER JOIN Users ON users_categories_rel.user_id = Users.id WHERE category_id = ?", category_id)
        return users_liking
    end

    # Uppdatera ett kategorinamn
    # 
    # @param [String] new_name det nya namnet på kategorin som vi kollar på
    # @param [Integer] category_id id:t på kategorin som vi kollar på
    # @see Model#connect_to_db
    def update_category_name(new_name, category_id)
        db = connect_to_db()
        db.execute('UPDATE Categories SET name = ? WHERE id = ?', new_name, category_id)
    end

    # Radera en kategori, samt alla tider och likes som hör till kategorin
    # 
    # @param [Integer] category_id id:t på kategorin som vi kollar på
    # @see Model#connect_to_db
    def delete_category(category_id)
        db = connect_to_db()
        db.execute("DELETE FROM Categories WHERE id=?", category_id)
        db.execute("DELETE FROM Times WHERE category_id = ?", category_id)
        db.execute("DELETE FROM users_categories_rel WHERE category_id = ?", category_id)
    end

    # Skapa en kategori
    # 
    # @param [String] name namnet på kategorin som vi kollar på
    # @param [Integer] user_id id:t på användaren som lägger till kategorin
    # @see Model#connect_to_db
    def insert_category(name, user_id)
        db = connect_to_db()
        db.execute('INSERT INTO Categories (name, user_id) VALUES (?, ?)', name, user_id)
    end

    # Hämta en viss tid, via tidens id
    # 
    # @param [Integer] time_id id:t på tiden som vi kollar på
    # @see Model#connect_to_db
    # @return [Hash] en hash som beskriver tidens attribut
    def get_time(time_id)
        db = connect_to_db()
        time = db.execute('SELECT * FROM Times WHERE id = ?', time_id).first
        return time
    end

    # Skapa en ny tid i databasen
    # 
    # @param [String] time_string tiden formaterad som en sträng
    # @param [String] data datumet som tiden läggs till (nu) i form av en sträng
    # @param [Integer] category_id id:t på kategorin som vi lägger till tiden i
    # @param [Integer] user_id id:t på användaren som lägger till tiden
    # @see Model#connect_to_db
    def insert_time(time_string, date, category_id, user_id)
        db = connect_to_db()
        db.execute('INSERT INTO Times (time, date, category_id, user_id) VALUES (?, ?, ?, ?)', time_string, date, category_id, user_id)
    end

    # Radera en tid från databasen
    # 
    # @param [Integer] time_id id:t på tiden som vi ska radera
    # @see Model#connect_to_db
    def delete_time(time_id)
        db = connect_to_db()
        db.execute("DELETE FROM Times WHERE id = ?", time_id)
    end

    # Hämta en användare med ett visst användarnamn
    # 
    # @param [String] username användarnamnet som vi ska söka efter
    # @see Model#connect_to_db
    # @return [Hash] en hash som beskriver användarens attribut
    def get_user_with_username(username)
        db = connect_to_db()
        user = db.execute("SELECT * FROM Users WHERE username=?", username).first
        return user
    end

    # Hämta en användar-id med ett visst användarnamn
    # 
    # @param [String] username användarnamnet som vi ska söka efter
    # @see Model#connect_to_db
    # @return [Integer] ett heltal som beskriver användar-id:t
    def get_user_id_with_username(username)
        db = connect_to_db()
        user_id = db.execute("SELECT id FROM Users WHERE username=?", username).first
        return user_id
    end
    
    # Hämta en användare med ett visst id
    # 
    # @param [Integer] id användar-id:t som vi ska söka efter
    # @see Model#connect_to_db
    # @return [Hash] en hash som beskriver användarens attribut
    def get_user(id)
        db = connect_to_db()
        user = db.execute("SELECT * FROM Users WHERE id = ?", id).first
        return user
    end

    # Skapa en användare i databasen
    # 
    # @param [String] username användarnamnet
    # @param [String] password_digest det krypterade lösenordet
    # @see Model#connect_to_db
    def insert_user(username, password_digest)
        db = connect_to_db()
        db.execute('INSERT INTO Users (username, pw_digest) VALUES (?, ?)', username, password_digest)
    end

    # Hämta alla kategorier skapade av en viss användare
    # 
    # @param [Integer] user_id användar-id:t som vi ska söka efter
    # @see Model#connect_to_db
    # @return [Array] en array med alla kategorier (som beskrivs av hashes)
    def get_all_categories_by_user_id(user_id)
        db = connect_to_db()
        categories = db.execute("SELECT * FROM Categories WHERE user_id = ?", user_id)
        return categories
    end

    # Hämta alla tider skapade av en viss användare
    # 
    # @param [Integer] user_id användar-id:t som vi ska söka efter
    # @see Model#connect_to_db
    # @return [Array] en array med alla tider (som beskrivs av hashes)
    def get_all_times_by_user_id(user_id)
        db = connect_to_db()
        times = db.execute("SELECT * FROM Times WHERE user_id = ?", user_id)
        return times
    end

    # Hämta kategorinamnet för en kategori
    # 
    # @param [Integer] id id:t på kategorin som vi ska söka efter
    # @see Model#connect_to_db
    # @return [Hash] en hash som beskriver kategorins attribut
    def get_category_name(id)
        db = connect_to_db()
        name = db.execute("SELECT name FROM Categories WHERE id = ?", id).first
        return name
    end

    # Hämta alla kategorier gillade av en viss användare
    # 
    # @param [Integer] user_id användar-id:t som vi ska söka efter
    # @see Model#connect_to_db
    # @return [Array] en array med alla kategorier (som beskrivs av hashes)
    def get_all_categories_liked_by_user(user_id)
        db = connect_to_db()
        categories_liking = db.execute("SELECT * FROM users_categories_rel INNER JOIN Categories ON users_categories_rel.category_id = Categories.id WHERE users_categories_rel.user_id = ?", user_id)
        return categories_liking
    end

    # Uppdatera en användares lösenord
    # 
    # @param [String] password_digest det nya krypterade lösenordet
    # @param [Integer] id användar-id:t hos användaren som vi ska byta lösen på
    # @see Model#connect_to_db
    def update_password(password_digest, id)
        db = connect_to_db()
        db.execute("UPDATE Users SET pw_digest = ? WHERE id = ?", password_digest, id)
    end

    # Skapa en "like", dvs en relation mellan Users och Categories
    # 
    # @param [Integer] user_id användar-id:t som vi ska skapa relationen med
    # @param [Integer] category_id kategori-id:t som vi ska skapa relationen med
    # @see Model#connect_to_db
    def insert_rel(user_id, category_id)
        db = connect_to_db()
        db.execute("INSERT INTO users_categories_rel (user_id, category_id) VALUES (?, ?)", user_id, category_id)
    end
    
    # Radera en "like", dvs en relation mellan Users och Categories
    # 
    # @param [Integer] user_id användar-id:t som vi ska skapa relationen med
    # @param [Integer] category_id kategori-id:t som vi ska skapa relationen med
    # @see Model#connect_to_db
    def delete_rel(user_id, category_id)
        db = connect_to_db()
        db.execute("DELETE FROM users_categories_rel WHERE user_id = ? AND category_id = ?", user_id, category_id)
    end

end