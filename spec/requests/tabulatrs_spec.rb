require 'spec_helper'

describe "Tabulatrs" do

  Mongoid.master.collections.select do |collection|
    collection.name !~ /system/
  end.each(&:drop)

  names = ["lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
  "adipisicing", "elit", "sed", "eiusmod", "tempor", "incididunt", "labore",
  "dolore", "magna", "aliqua", "enim", "minim", "veniam,", "quis", "nostrud",
  "exercitation", "ullamco", "laboris", "nisi", "aliquip", "commodo",
  "consequat", "duis", "aute", "irure", "reprehenderit", "voluptate", "velit",
  "esse", "cillum", "fugiat", "nulla", "pariatur", "excepteur", "sint",
  "occaecat", "cupidatat", "non", "proident", "sunt", "culpa", "qui",
  "officia", "deserunt", "mollit", "anim", "est", "laborum"]

  let!(:vendor1) { Vendor.create!(:name => "ven d'or", :active => true, :description => "blarg") }
  let!(:vendor2) { Vendor.create!(:name => 'producer', :active => true, :description => "vendor extrordinare") }
  let!(:tag1)    { Tag.create!(:title => 'foo') }
  let!(:tag2)    { Tag.create!(:title => 'bar') }
  let!(:tag3)    { Tag.create!(:title => 'fubar') }
  let!(:ids)     { [] }
  let!(:total)   { names.count }
  let!(:page_size)   { 10 }

  before do
    names.each_with_index {|n,i| Product.create!(:title => n, :active => true, :price => 10.0+i,
        :description => "blah blah #{i}", :vendor => i.even? ? vendor1 : vendor2) }
  end

  describe "General data" do
    it "works in general" do
      get index_simple_products_path
      response.status.should be(200)
    end

    it "contains buttons" do
      visit index_simple_products_path
      [:submit_label, :select_all_label, :select_none_label, :select_visible_label,
        :unselect_visible_label, :select_filtered_label, :unselect_filtered_label
      ].each do |n|
        page.should have_button(Tabulatr::TABLE_OPTIONS[n])
      end
      page.should_not have_button(Tabulatr::TABLE_OPTIONS[:reset_label])
    end

    it "contains column headers" do
      visit index_simple_products_path
      ['Id','Title','Price','Active','Created At','Vendor Created At','Vendor Name','Tags Title','Tags Count'].each do |n|
        page.should have_content(n)
      end
    end

    it "contains other elements" do
      visit index_simple_products_path
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, total, 0, total))
    end

    it "contains the actual data" do
      visit index_simple_products_path
      page.should have_content(names[0])
      page.should have_content("true")
      page.should have_content("10.0")
      page.should have_content("--0--")
      #save_and_open_page
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, total, 0, total))
      page.should have_content("ven d'or")
    end

    it "correctly contains the association data" do
      product = Product.first
      [tag1, tag2, tag3].each_with_index do |tag, i|
        product.tags << tag
        visit index_simple_products_path
        page.should have_content tag.title
        page.should have_content(sprintf("--%d--", i+1))
      end
    end

    it "contains row identifiers" do
      visit index_simple_products_path
      Product.limit(10).each do |product|
        page.should have_css("#product_#{product.id}")
      end
    end
  end

  describe "Pagination" do
    it "pages up and down" do
      visit index_simple_products_path
      k = (names.length/10)+1
      k.times do |i|
        ((i*10)...[names.length, ((i+1)*10)].min).each do |j|
          page.should have_content(names[j])
        end
        if i==0
          page.should have_no_button('product_pagination_page_left')
        else
          page.should have_button('product_pagination_page_left')
        end
        if i==k-1
          page.should have_no_button('product_pagination_page_right')
        else
          page.should have_button('product_pagination_page_right')
          click_button('product_pagination_page_right')
        end
      end
      # ...and down
      k.times do |ii|
        i = k-ii-1
        ((i*10)...[names.length, ((i+1)*10)].min).each do |j|
          page.should have_content(names[j])
        end
        if i==k-1
          page.should have_no_button('product_pagination_page_right')
        else
          page.should have_button('product_pagination_page_right')
        end
        if i==0
          page.should have_no_button('product_pagination_page_left')
        else
          page.should have_button('product_pagination_page_left')
          click_button('product_pagination_page_left')
        end
      end
    end

    it "jumps to the correct page" do
      visit index_simple_products_path
      k = 1+names.length/10
      l = (1..k).entries.shuffle
      l.each do |ii|
        i = ii-1
        fill_in("product_pagination[page]", :with => ii.to_s)
        click_button("Apply")
        ((i*10)...[names.length, ((i+1)*10)].min).each do |j|
          page.should have_content(names[j])
        end
        if i==0
          page.should have_no_button('product_pagination_page_left')
        else
          page.should have_button('product_pagination_page_left')
        end
        if i==k-1
          page.should have_no_button('product_pagination_page_right')
        else
          page.should have_button('product_pagination_page_right')
        end
      end
    end

    it "changes the page size" do
      visit index_simple_products_path
      [50,20,10].each do |s|
        select s.to_s, :from => "product_pagination[pagesize]"
        click_button "Apply"
        s.times do |i|
          page.should have_content(names[i])
        end
        page.should_not have_content(names[s])
      end
    end
  end

  describe "Filters" do
    it "filters" do
      visit index_simple_products_path
      #save_and_open_page
      fill_in("product_filter[title]", :with => "lorem")
      click_button("Apply")
      page.should have_content("lorem")
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 1, names.length, 0, 1))
      fill_in("product_filter[title]", :with => "loreem")
      click_button("Apply")
      page.should_not have_content("lorem")
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 0, names.length, 0, 0))
    end

    it "filters with like" do
      visit index_filters_products_path
      %w{a o lo lorem}.each do |str|
        fill_in("product_filter[title][like]", :with => str)
        click_button("Apply")
        page.should have_content(str)
        tot = (names.select do |s| s.match Regexp.new(str) end).length
        #save_and_open_page
        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], [10,tot].min, names.length, 0, tot))
      end
    end

    it "filters with range" do
      visit index_filters_products_path
      n = names.length
      (0..n/2).each do |i|
        fill_in("product_filter[price][from]", :with => (10+i).to_s)
        fill_in("product_filter[price][to]", :with => "")
        click_button("Apply")
        tot = n-i
        #save_and_open_page
        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], [10,tot].min, n, 0, tot))
        fill_in("product_filter[price][to]", :with => (10+i).to_s)
        fill_in("product_filter[price][from]", :with => "")
        click_button("Apply")
        tot = i+1
        #save_and_open_page
        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], [10,tot].min, n, 0, tot))
        fill_in("product_filter[price][from]", :with => (10+i).to_s)
        fill_in("product_filter[price][to]", :with => (10+n-i-1).to_s)
        click_button("Apply")
        tot = n-i*2
        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], [10,tot].min, n, 0, tot))
      end
    end

    context "filters compound keys" do

      it "on column" do
        visit index_compound_products_path

        fill_in("product_filter[title,description][like]", :with => "ullamco")
        click_button("Apply")
        found = 1

        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], found, total, 0, found))

        fill_in("product_filter[title,description][like]", :with => "lab")
        click_button("Apply")
        found = Product.where("title LIKE \"%lab%\" OR description LIKE \"%lab%\"").count

        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], [10,found].min, total, 0, found))
      end

      it "on association" do
        visit index_compound_products_path

        fill_in("product_filter[title,description][like]", :with => "")
        fill_in("product_filter[__association][vendor][name,description][like]", :with => "vendor")
        click_button("Apply")
        found = Product.joins(:vendor).where("vendors.name LIKE \"%vendor%\" OR vendors.description LIKE \"%vendor%\"").count

        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], [10,found].min, total, 0, found))
      end
    end
  end

  describe "Sorting" do
    it "knows how to sort" do
      visit index_sort_products_path
      # save_and_open_page
      (1..10).each do |i|
        page.should have_content names[-i]
      end
      click_button("product_sort_title_desc")
      snames = names.sort
      (1..10).each do |i|
        page.should have_content snames[-i]
      end
      click_button("product_sort_title_asc")
      (1..10).each do |i|
        page.should have_content snames[i-1]
      end
    end
  end

  describe "statefulness" do
    it "sorts statefully" do
      visit index_stateful_products_path
      snames = names.sort.reverse

      click_button("product_sort_title_desc")
      10.times do |i|
        page.should have_content snames[i]
      end

      visit index_stateful_products_path
      10.times do |i|
        page.should have_content snames[i]
      end

      click_button("Reset")
      10.times do |i|
        page.should have_content names[i]
      end
    end

    it "filters statefully" do
      Capybara.reset_sessions!
      visit index_stateful_products_path
      fill_in("product_filter[title]", :with => "lorem")
      click_button("Apply")
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 1, total, 0, 1))

      visit index_stateful_products_path
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 1, total, 0, 1))

      click_button("Reset")
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, total, 0, total))
    end

    it "selects statefully" do
      visit index_stateful_products_path
      fill_in("product_filter[title]", :with => "")
      click_button("Apply")
      select_per_page = 4

      (total/10).times do |i|
        1.upto(select_per_page).each do |j|
          check("product_checked_#{Product.find((page_size*i)+j).id}")
        end

        click_button("Apply")
        selected = select_per_page*(i+1)

        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, total, selected, total))
        click_button('product_pagination_page_right')
      end

      visit index_stateful_products_path
      selected = select_per_page * page_size

      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, total, selected, total))
      click_button("Reset")

      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, total, 0, total))
    end

  end

  describe "Select and Batch actions" do
    it "knows how to interpret the select_... buttons" do
      # Showing 10, total 54, selected 54, matching 54
      n = names.length
      visit index_select_products_path
      click_button('Select All')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, n, n))
      click_button('Select None')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, 0, n))
      click_button('Select visible')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, 10, n))
      click_button('Select None')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, 0, n))
      fill_in("product_filter[title][like]", :with => "a")
      click_button("Apply")
      tot = (names.select do |s| s.match /a/ end).length
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, 0, tot))
      click_button('Select filtered')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, tot, tot))
      fill_in("product_filter[title][like]", :with => "")
      click_button("Apply")
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, tot, n))
      click_button("Unselect visible")
      tot -= (names[0..9].select do |s| s.match /a/ end).length
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, tot, n))
      click_button('Select None')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, 0, n))
      click_button('Select All')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, n, n))
      fill_in("product_filter[title][like]", :with => "a")
      click_button("Apply")
      tot = (names.select do |s| s.match /a/ end).length
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, n, tot))
      click_button('Unselect filtered')
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, n-tot, tot))
      fill_in("product_filter[title][like]", :with => "")
      click_button("Apply")
      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], 10, n, n-tot, n))
    end

    it "knows how to select and apply batch actions" do
      select_per_page = 4

      visit index_select_products_path
      (total/page_size).times do |i|
        1.upto(select_per_page).each do |j|
          check("product_checked_#{Product.find((page_size*i)+j).id}")
        end
        click_button("Apply")

        selected = select_per_page*(i+1)
        page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, total, selected, total))

        click_button('product_pagination_page_right')
      end

      select 'Delete', :from => 'product_batch'
      click_button("Apply")
      select = total-(select_per_page*(total/10))

      page.should have_content(sprintf(Tabulatr::TABLE_OPTIONS[:info_text], page_size, select, 0, select))
    end
  end

end





