/*
 * window.h
 *
 *  Created on: Mar 15, 2017
 *      Author: jan
 */

#ifndef WINDOW_HPP_
#define WINDOW_HPP_

#include <common.hpp>
#include <widget.hpp>
#include "display.h"
#include "font.h"

class Window : public Widget {
public:
	Window(const char *title, font_t font, coords_t size);
	~Window();

	void setMainWidget(Widget *w);
	coords_t getAvailableArea();

private:
	void draw(coords_t offset) override;
	void input(GUIEvent_t *ev) override;
	void drawChildren(coords_t offset) override;

	Widget::Type getType() override { return Widget::Type::Window; };

	static constexpr color_t Border = COLOR_BLACK;
	static constexpr color_t TitleBackground = COLOR(65, 64, 59);
	static constexpr color_t TitleForeground = COLOR(215, 214, 207);
	static constexpr color_t CloseAreaBackground = COLOR(229, 99, 42);
	static constexpr color_t CloseAreaForeground = COLOR_BG_DEFAULT;

    char *title;
    font_t font;
    Widget *lastTopWidget;
    Widget *lastSelected;
    bool lastPopup;
};

#endif /* WINDOW_HPP_ */
