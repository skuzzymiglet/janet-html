(defn escape [str]
  (let [str (string str)]
    (->> (string/replace-all "&" "&amp;" str)
         (string/replace-all "<" "&lt;")
         (string/replace-all ">" "&gt;")
         (string/replace-all "\"" "&quot;")
         (string/replace-all "'" "&#x27;")
         (string/replace-all "/" "&#x2F;")
         (string/replace-all "%" "&#37;"))))


(defn raw [val]
  [:text val])


(defn doctype [version &opt style]
  (let [key [version (or style "")]
        doctypes {[:html5 ""] (raw "<!DOCTYPE HTML>")
                  [:html4 :strict] (raw `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">`)
                  [:html4 :transitional] (raw `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">`)
                  [:html4 :frameset] (raw `<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">`)
                  [:xhtml1.0 :strict] (raw `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">`)
                  [:xhtml1.0 :transitional] (raw `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">`)
                  [:xhtml1.0 :frameset] (raw `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">`)
                  [:xhtml1.1 ""] (raw `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">`)
                  [:xhtml1.1 :basic] (raw `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">`)}]
    (get doctypes key "")))


(def- void-elements
  [:area :base :br :col :embed
   :hr :img :input :keygen :link
   :meta :param :source :track :wbr])


(defn- void-element?
  [name]
  (some (partial = name) void-elements))


(defn- text-element?
  [name]
  (= name :text))


(defn- attr-reducer
  [acc [attr value]]
  (string acc " " attr `="` value `"`))


(defn- create-attrs
  [attrs]
  (reduce attr-reducer "" (map (fn [[x y]] [x y]) (pairs attrs))))


(defn- element-name [name]
  (->> (string/split "." name)
       (first)))


(defn- opening-tag [name attrs]
  (let [dot-classes (drop 1 (string/split "." name))
        string-classes (let [class (get attrs :class)]
                         (case (type class)
                           :string (string/split " " class)
                           :tuple class
                           :array class
                           []))
        classes (string/trim (string/join [;dot-classes ;string-classes] " "))

        attrs (if (empty? classes)
                attrs
                (merge attrs {:class classes}))]

    (string "<" (element-name name) (create-attrs attrs) (if (void-element? name) " />" ">"))))


(defn- closing-tag
  [name]
  (string "</" (element-name name) ">"))


(defn- first-child
  [children]
  (if (indexed? children)
    (when (not (empty? children))
      (first children))
    children))


(defn- valid-children?
  [children]
  (or (indexed? children)
      (number? children)
      (string? children)
      (buffer? children)))


(defn- create-children
  [create children]

  (defn child-reducer
    [acc child]
    (string acc (create child)))

  (let [child (first-child children)]
    (cond
      (indexed? child) (reduce child-reducer "" children)
      (keyword? child) (create children)
      (all valid-children? children) (as-> children ?
                                           (map |(if (indexed? $) (create $) (escape $)) ?)
                                           (string/join ?))
      (nil? child) ""
      (empty? child) ""
      :else children)))


(defn- validate-element
  [name attrs children]
  (unless (keyword? name)
    (error "tag name must be a keyword, such as :a, :div or :h3"))
  (unless (dictionary? attrs)
    (error "tag attributes must be a dictionary, such as {:class \"code\" }"))
  (unless (valid-children? children)
    (error "tag children must be a string, number, array, or tuple")))


(defn- create-element
  [create name attrs children]
  (validate-element name attrs children)
  (cond
    (void-element? name) (opening-tag name attrs)
    (text-element? name) (first children)
    :else (string (opening-tag name attrs)
                  (create-children create children)
                  (closing-tag name))))


(defn- create
  [element]
  (cond
    (nil? element)
    ""

    (not (indexed? element))
    (escape (string element))

    (indexed? element)
    (if (all valid-children? element)
      (string/join (map create element))
      (let [[name attrs] element]
        (if (dictionary? attrs)
          (create-element create name attrs (filter truthy? (drop 2 element)))
          (create-element create name {} (filter truthy? (drop 1 element))))))))


(defn encode [& args]
  (string/join (map create args)))

(def html encode)
